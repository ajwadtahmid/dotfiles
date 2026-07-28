#!/bin/bash

################################################################################
#                   FEDORA DEVELOPER SETUP SCRIPT
#
#   An installation script for Fedora Linux
#
#   Usage: chmod +x install.sh && sudo bash install.sh
#
#   Two install modes (selected at runtime, or via --mode flag):
#
#     1) devcontainer Base system + shell + apps + Docker + ESSENTIAL dev
#                     tools (Python, Node, Flutter) + dev container template
#                     (sections 1-7, 9-12). Skips the OPTIONAL native toolchain
#                     (section 8: extra languages + local databases) — those
#                     live inside containers. This is the recommended default.
#
#     2) baremetal    Everything above PLUS the optional native dev toolchain
#                     (Go, Rust, Java/Gradle, Expo, PostgreSQL, MariaDB) on the
#                     host (section 8). Optionally also scaffolds dev containers.
#
#   Optional --shell flag selects the default shell to set up:
#     --shell zsh    oh-my-zsh + powerlevel10k, set as the login shell
#     --shell bash   keep plain bash (default if not specified interactively)
#
#   Non-interactive examples:
#     sudo bash install.sh --mode devcontainer --shell zsh
#     sudo bash install.sh --mode baremetal
#     sudo bash install.sh --mode baremetal --with-devcontainer
#
#   Tested on: Fedora 43/44
#
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Absolute path to this script's directory, so we can install helper files that
# ship alongside it (e.g. bin/devinit) regardless of the caller's cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
#                         CONFIGURATION SECTION
#                    (Customize before running the script)
################################################################################

# Git Configuration (set your details here)
GIT_USERNAME="Ajwad Tahmid"           # Change to your name
GIT_EMAIL="dev@ajwadtahmid.com"       # Change to your email

################################################################################
#                         HELPER FUNCTIONS
################################################################################

print_section() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Non-critical steps that may legitimately fail (a removed Flatpak ref, a
# transient network error, an unavailable SDKMAN build) are run through soft().
# Because the command runs inside an `if`, `set -e` will NOT abort the script;
# instead the failure is recorded in WARNINGS and reported in the final summary.
WARNINGS=()
soft() {
    local desc="$1"; shift
    if "$@"; then
        return 0
    else
        WARNINGS+=("$desc")
        print_warning "Skipped (failed): $desc"
        return 0
    fi
}

# Append a single line to the user's ~/.bashrc exactly once (idempotent).
# Optionally precedes it with a comment header on first insertion.
append_bashrc() {
    local line="$1" comment="${2:-}"
    local bashrc="$USER_HOME/.bashrc"
    if sudo -Hu "$SUDO_USER" grep -Fxq "$line" "$bashrc" 2>/dev/null; then
        print_info "Already in ~/.bashrc: ${comment:-$line}"
        return 0
    fi
    echo "" | sudo -Hu "$SUDO_USER" tee -a "$bashrc" > /dev/null
    [[ -n "$comment" ]] && echo "$comment" | sudo -Hu "$SUDO_USER" tee -a "$bashrc" > /dev/null
    echo "$line" | sudo -Hu "$SUDO_USER" tee -a "$bashrc" > /dev/null
    print_success "Added to ~/.bashrc: ${comment:-$line}"
}

# Same as append_bashrc but for ~/.zshrc (used by the optional zsh setup).
append_zshrc() {
    local line="$1" comment="${2:-}"
    local zshrc="$USER_HOME/.zshrc"
    if sudo -Hu "$SUDO_USER" grep -Fxq "$line" "$zshrc" 2>/dev/null; then
        print_info "Already in ~/.zshrc: ${comment:-$line}"
        return 0
    fi
    echo "" | sudo -Hu "$SUDO_USER" tee -a "$zshrc" > /dev/null
    [[ -n "$comment" ]] && echo "$comment" | sudo -Hu "$SUDO_USER" tee -a "$zshrc" > /dev/null
    echo "$line" | sudo -Hu "$SUDO_USER" tee -a "$zshrc" > /dev/null
    print_success "Added to ~/.zshrc: ${comment:-$line}"
}

# Append a shell-agnostic env/PATH line to the login shell(s) the user actually
# uses: always bash, plus zsh when zsh was selected. Use this for PATH/exports
# (which work in both shells) — NOT for shell-specific inits like
# `zoxide init bash` vs `zoxide init zsh`. Idempotent per file.
append_login_rc() {
    local line="$1" comment="${2:-}"
    append_bashrc "$line" "$comment"
    [[ "$SHELL_CHOICE" == "zsh" ]] && append_zshrc "$line" "$comment"
    return 0
}

# Ensure the nvm loader is present in the given rc file. nvm's installer wires
# only the single profile it detects from $SHELL, so the other shell can end up
# without it. Matched on the "nvm.sh" substring because nvm writes the same
# source line with a trailing comment, which an exact-line check would miss.
ensure_nvm_rc() {
    local rc="$1"
    if sudo -Hu "$SUDO_USER" grep -q 'nvm\.sh' "$rc" 2>/dev/null; then
        print_info "nvm already loaded in $(basename "$rc")"
        return 0
    fi
    { echo ""
      echo "# nvm"
      echo 'export NVM_DIR="$HOME/.nvm"'
      echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    } | sudo -Hu "$SUDO_USER" tee -a "$rc" > /dev/null
    print_success "Added nvm loader to $(basename "$rc")"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run with sudo (e.g. 'sudo bash install.sh')"
        exit 1
    fi
    if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" == "root" ]]; then
        print_error "Run this script with sudo from a normal user account, not as root directly."
        print_error "The script needs \$SUDO_USER to install user-scoped tools (NVM, Rust, Flutter, etc.)."
        exit 1
    fi
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
        print_error "Could not resolve home directory for user '$SUDO_USER'."
        exit 1
    fi
    export USER_HOME
}

################################################################################
#                         INSTALL MODE SELECTION
#
#   Two modes:
#     baremetal    -> all sections, incl. optional dev tools (§8) + optional §11
#     devcontainer -> everything except the optional dev tools in §8
#
#   Mode and options can be set via flags (--mode, --with-devcontainer) or
#   chosen interactively when not supplied.
################################################################################

# Defaults (may be overridden by flags or the interactive prompt)
INSTALL_MODE=""          # "baremetal" or "devcontainer"
WITH_DEVCONTAINER=false  # baremetal-only: also run section 11
SHELL_CHOICE=""          # "zsh" or "bash" (default shell to set up)
ZED_SETTINGS_NEEDS_MANUAL=false  # set true when a Zed settings.json already exists

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                INSTALL_MODE="${2:-}"
                shift 2
                ;;
            --mode=*)
                INSTALL_MODE="${1#*=}"
                shift
                ;;
            --with-devcontainer)
                WITH_DEVCONTAINER=true
                shift
                ;;
            --shell)
                SHELL_CHOICE="${2:-}"
                shift 2
                ;;
            --shell=*)
                SHELL_CHOICE="${1#*=}"
                shift
                ;;
            -h|--help)
                # Print the banner: skip the shebang, strip the leading '#' from
                # comment lines, and stop at the first line of actual code.
                awk 'NR==1{next} /^#/{sub(/^#/,""); print; next} /^[[:space:]]*$/{next} {exit}' "$0"
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1"
                exit 1
                ;;
        esac
    done

    if [[ -n "$INSTALL_MODE" && "$INSTALL_MODE" != "baremetal" && "$INSTALL_MODE" != "devcontainer" ]]; then
        print_error "Invalid --mode '$INSTALL_MODE' (expected 'baremetal' or 'devcontainer')"
        exit 1
    fi
    if [[ -n "$SHELL_CHOICE" && "$SHELL_CHOICE" != "zsh" && "$SHELL_CHOICE" != "bash" ]]; then
        print_error "Invalid --shell '$SHELL_CHOICE' (expected 'zsh' or 'bash')"
        exit 1
    fi
}

select_shell() {
    # If shell already supplied via flag, don't prompt for it.
    if [[ -n "$SHELL_CHOICE" ]]; then
        print_info "Default shell: $SHELL_CHOICE"
        return 0
    fi
    print_section "SELECT DEFAULT SHELL"
    echo "  zsh  - oh-my-zsh + powerlevel10k + autosuggestions & syntax"
    echo "         highlighting, set as your default login shell."
    echo "  bash - keep bash as the default shell, with the oh-my-posh prompt."
    echo ""
    read -p "Set up and use zsh (oh-my-zsh + powerlevel10k)? [y/N]: " ZSH_CHOICE
    case "$ZSH_CHOICE" in
        [yY]|[yY][eE][sS]) SHELL_CHOICE="zsh" ;;
        *)                 SHELL_CHOICE="bash" ;;
    esac
    print_info "Default shell: $SHELL_CHOICE"
}

select_mode() {
    # If mode already supplied via flag, don't prompt for it.
    if [[ -z "$INSTALL_MODE" ]]; then
        print_section "SELECT INSTALL MODE"
        echo "  1) Devcontainer- Base system + shell + apps + Docker + essential"
        echo "                   dev tools (Python/Node/Flutter) + dev container"
        echo "                   template. Optional languages/DBs live in"
        echo "                   containers, not on the host. (Recommended)"
        echo ""
        echo "  2) Baremetal   - Everything above PLUS the optional dev toolchain"
        echo "                   (Go, Rust, Java, Expo, local databases) on host."
        echo ""
        read -p "Enter choice [1-2, default 1]: " MODE_CHOICE
        case "$MODE_CHOICE" in
            1|"") INSTALL_MODE="devcontainer" ;;
            2)    INSTALL_MODE="baremetal" ;;
            *)
                print_warning "Invalid choice. Defaulting to devcontainer."
                INSTALL_MODE="devcontainer"
                ;;
        esac
    fi

    # For baremetal, optionally also set up dev containers (section 11).
    if [[ "$INSTALL_MODE" == "baremetal" && "$WITH_DEVCONTAINER" == "false" ]]; then
        read -p "Also set up dev containers (devcontainer CLI + template)? [y/N]: " DC_CHOICE
        case "$DC_CHOICE" in
            [yY]|[yY][eE][sS]) WITH_DEVCONTAINER=true ;;
            *) WITH_DEVCONTAINER=false ;;
        esac
    fi

    print_info "Install mode: $INSTALL_MODE"
    if [[ "$INSTALL_MODE" == "baremetal" ]]; then
        print_info "Dev containers: $([[ "$WITH_DEVCONTAINER" == "true" ]] && echo "yes" || echo "no")"
    fi
}

################################################################################
#                    SECTION 1: SYSTEM UPDATES & RPM FUSION
################################################################################

section_system_updates() {
    print_section "SYSTEM UPDATES & RPM FUSION"

    print_info "Updating system packages..."
    dnf upgrade -y
    print_success "System updated"

    # dnf5-plugins provides `dnf config-manager`, used later to add the Mullvad
    # (Section 6) and Docker (Section 9) repositories. Not always present on a
    # fresh/minimal Fedora install, so ensure it here before anything needs it.
    print_info "Installing dnf5-plugins (provides 'dnf config-manager')..."
    dnf install -y dnf5-plugins
    print_success "dnf5-plugins installed"

    print_info "Installing RPM Fusion repositories..."
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                      https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    print_success "RPM Fusion installed"
}

################################################################################
#               SECTION 2: CORE SOFTWARE
#
#   Build/CLI toolchain plus the desktop essentials this personal machine is
#   built around (steam, mangohud, goverlay, etc.). Shell integration for the
#   CLI tools installed here is wired up later in Section 5 (Shell Setup).
################################################################################

section_core_software() {
    print_section "CORE SOFTWARE"

    print_info "Installing core software..."
    dnf install -y \
        gcc \
        gcc-c++ \
        make \
        cmake \
        clang \
        clang-tools-extra \
        ninja-build \
        gtk3-devel \
        libXScrnSaver-devel \
        libXtst-devel \
        mesa-libGL-devel \
        libXrandr-devel \
        libXcursor-devel \
        libsecret-devel \
        pkgconfig \
        libX11-devel \
        libXrender-devel \
        libcurl-devel \
        unzip \
        xz \
        zip \
        mesa-libGLU \
        git \
        git-lfs \
        htop \
        fastfetch \
        zsh \
        curl \
        jq \
        ripgrep \
        fzf \
        gh \
        zoxide \
        tmux \
        steam \
        gnome-disk-utility \
        mangohud \
        goverlay

    print_info "Initializing Git LFS..."
    sudo -Hu "$SUDO_USER" git lfs install
    print_success "Git LFS initialized"

    # ── Modern CLI tools (best-effort) ────────────────────────────────────────
    # Installed one at a time via soft() so a package that's unavailable on this
    # Fedora release only skips itself instead of aborting the whole batch.
    #   eza   → modern ls        bat      → cat with syntax highlighting
    #   fd    → friendlier find  git-delta→ nicer git diffs
    #   btop  → resource monitor tealdeer (tldr) → concise man pages
    print_info "Installing modern CLI tools..."
    MODERN_CLI=( eza bat fd-find git-delta btop tealdeer )
    for tool in "${MODERN_CLI[@]}"; do
        print_info "  → $tool"
        soft "CLI tool: $tool" dnf install -y "$tool"
    done

    # lazygit (git TUI) is not in Fedora's base repos — install it from the
    # dejan/lazygit COPR. 'dnf copr' is provided by dnf5-plugins (Section 1).
    print_info "Installing lazygit (COPR dejan/lazygit)..."
    if soft "enable COPR dejan/lazygit" dnf copr enable -y dejan/lazygit; then
        soft "CLI tool: lazygit" dnf install -y lazygit
    fi
}

################################################################################
#              SECTION 3: FLATPAK & FLATHUB SETUP
################################################################################

section_flatpak() {
    print_section "FLATPAK & FLATHUB SETUP"

    print_info "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    print_success "Flathub added"

    # Installed one-by-one (not as a single batch) so that a single removed or
    # renamed ref only skips that app and is reported at the end, instead of
    # aborting the whole Flatpak install.
    FLATPAK_APPS=(
        io.github.kolunmi.Bazaar
        com.discordapp.Discord
        com.brave.Browser
        app.zen_browser.zen
        org.videolan.VLC
        io.ente.photos
        com.github.tchx84.Flatseal
        org.onlyoffice.desktopeditors
        com.vysp3r.ProtonPlus
        org.flameshot.Flameshot
        org.qbittorrent.qBittorrent
        im.riot.Riot
        com.obsproject.Studio
        io.github.peazip.PeaZip
        org.mozilla.Thunderbird
        org.kde.kdenlive
        io.freetubeapp.FreeTube
        com.github.Matoking.protontricks
        com.usebruno.Bruno
        org.godotengine.Godot
        fr.handbrake.ghb
        net.cozic.joplin_desktop
        net.mullvad.MullvadBrowser
    )

    print_info "Installing ${#FLATPAK_APPS[@]} Flatpak applications..."
    for app in "${FLATPAK_APPS[@]}"; do
        print_info "  → $app"
        soft "Flatpak app: $app" flatpak install -y flathub "$app"
    done

    print_success "Flatpak applications processed"
}

#   Uncomment the apps you need, otherwise keep commented.
#
#     flatpak install flathub dev.zed.Zed
#     flatpak install flathub org.fedoraproject.MediaWriter
#     flatpak install flathub chat.schildi.desktop
#     flatpak install flathub org.gimp.GIMP
#     flatpak install flathub org.gnome.Boxes
#     flatpak install flathub com.mojang.Minecraft
#     flatpak install flathub dev.vencord.Vesktop
#     flatpak install flathub com.heroicgameslauncher.hgl
#     flatpak install flathub org.kde.okular
#     flatpak install flathub com.protonvpn.www
#     flatpak install flathub com.visualstudio.code

################################################################################
#              SECTION 4: GIT CONFIGURATION
#
#   Git is configured with the username and email set at the top of the script.
################################################################################

section_git_config() {
    print_section "GIT CONFIGURATION"

    print_info "Configuring Git..."
    sudo -Hu "$SUDO_USER" git config --global user.name "$GIT_USERNAME"
    sudo -Hu "$SUDO_USER" git config --global user.email "$GIT_EMAIL"
    sudo -Hu "$SUDO_USER" git config --global pull.rebase false
    sudo -Hu "$SUDO_USER" git config --global init.defaultBranch main
    # Set the upstream automatically on first push of a new branch.
    sudo -Hu "$SUDO_USER" git config --global push.autoSetupRemote true
    # Normalize line endings to LF on commit (correct for Linux/macOS).
    sudo -Hu "$SUDO_USER" git config --global core.autocrlf input
    print_success "Git configured"

    print_info "Adding Git aliases (lg, st, undo)..."
    sudo -Hu "$SUDO_USER" git config --global alias.lg "log --oneline --graph --decorate --all"
    sudo -Hu "$SUDO_USER" git config --global alias.st "status -sb"
    sudo -Hu "$SUDO_USER" git config --global alias.undo "reset --soft HEAD~1"
    print_success "Git aliases configured"

    print_info "Git configuration:"
    sudo -Hu "$SUDO_USER" git config --global --list | grep -E "user\.|pull\.|init\."

    print_info "To update Git config later, run:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
}

################################################################################
#              SECTION 5: SHELL SETUP
#
#   The single home for everything that writes to ~/.bashrc / ~/.zshrc:
#     - JetBrains Mono Nerd Font + Konsole default font
#     - ~/.local/bin on PATH, zoxide + fzf + atuin hooks
#     - bash  -> oh-my-posh prompt (agnosterplus theme)
#     - zsh   -> oh-my-zsh + powerlevel10k + autosuggestions/syntax-highlighting,
#                then set as the login shell
#
#   Atuin is installed here too, right next to its hooks. The user chose bash or
#   zsh at the start; bash stays the default unless zsh was selected.
################################################################################

# Install the JetBrains Mono Nerd Font system-wide (needed for the p10k /
# oh-my-posh glyphs) unless a Nerd Font is already present. Idempotent.
install_nerd_font() {
    if command -v fc-list >/dev/null 2>&1 && fc-list | grep -qi "Nerd Font"; then
        print_info "A Nerd Font is already installed — skipping font install"
        return 0
    fi
    print_info "Installing JetBrains Mono Nerd Font..."
    local tmp; tmp=$(mktemp -d)
    if soft "JetBrains Mono Nerd Font download" curl -fsSL -o "$tmp/JetBrainsMono.zip" \
            https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip; then
        install -d /usr/share/fonts/nerd-fonts
        unzip -oq "$tmp/JetBrainsMono.zip" -d /usr/share/fonts/nerd-fonts
        fc-cache -f >/dev/null 2>&1 || true
        print_success "JetBrains Mono Nerd Font installed"
    fi
    rm -rf "$tmp"
}

# Set Konsole's default font to JetBrainsMono Nerd Font. Uses kwriteconfig,
# which just edits config files (no live KDE session needed), so it's safe to
# run from the installer and re-run any time. Updates the existing default
# profile so other Konsole customizations are preserved; creates one only if
# there is no default profile yet. No-op if the KDE tools aren't installed.
configure_konsole_font() {
    local kwrite kread
    kwrite=$(command -v kwriteconfig6 2>/dev/null || command -v kwriteconfig5 2>/dev/null || true)
    kread=$(command -v kreadconfig6 2>/dev/null  || command -v kreadconfig5 2>/dev/null  || true)
    if [[ -z "$kwrite" ]]; then
        print_info "kwriteconfig (KDE) not found — skipping Konsole font setup."
        return 0
    fi

    local font="JetBrainsMono Nerd Font,12,-1,5,50,0,0,0,0,0"
    local kdir="$USER_HOME/.local/share/konsole"
    install -d -o "$SUDO_USER" -g "$SUDO_USER" "$kdir"

    # Reuse the current default profile if there is one; otherwise create one.
    local default_profile="" profile_file
    [[ -n "$kread" ]] && default_profile=$(sudo -Hu "$SUDO_USER" "$kread" \
        --file konsolerc --group "Desktop Entry" --key DefaultProfile 2>/dev/null || true)

    if [[ -n "$default_profile" && -f "$kdir/$default_profile" ]]; then
        profile_file="$kdir/$default_profile"
        print_info "Updating Konsole font in existing profile: $default_profile"
    else
        profile_file="$kdir/Dotfiles.profile"
        sudo -Hu "$SUDO_USER" "$kwrite" --file "$profile_file" --group General --key Name "Dotfiles" || true
        sudo -Hu "$SUDO_USER" "$kwrite" --file konsolerc --group "Desktop Entry" --key DefaultProfile "Dotfiles.profile" || true
        print_info "Created Konsole profile 'Dotfiles' and set it as default"
    fi

    soft "Konsole font (kwriteconfig)" sudo -Hu "$SUDO_USER" "$kwrite" \
        --file "$profile_file" --group Appearance --key Font "$font"
    print_success "Konsole default font set to JetBrainsMono Nerd Font (restart Konsole to apply)"
}

# Atuin (shell history). Installed here so its install and shell hooks live in
# one section. Its own installer wires the bash hook into ~/.bashrc; the zsh
# hook is added in section_shell_setup's zsh branch.
install_atuin() {
    print_section "ATUIN SHELL HISTORY MANAGER"

    if sudo -Hu "$SUDO_USER" bash -c 'command -v atuin >/dev/null 2>&1 || [ -x "$HOME/.local/bin/atuin" ] || [ -x "$HOME/.atuin/bin/atuin" ]'; then
        print_info "Atuin already installed — skipping"
    else
        print_info "Installing Atuin shell history manager (non-interactive)..."
        soft "Atuin" sudo -Hu "$SUDO_USER" bash -c 'curl --proto "=https" --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive'
    fi

    # Atuin's own installer wires the bash hook into ~/.bashrc, so we don't add
    # it here. If it ever stops doing that, uncomment the line below and re-run:
    # append_bashrc 'command -v atuin >/dev/null 2>&1 && eval "$(atuin init bash)"' '# atuin (shell history)'
}

# Everyday aliases for whichever shell(s) are in use. Called after the shell's
# rc file is in its final state — oh-my-zsh replaces ~/.zshrc when it installs,
# so anything written before that would be lost to its backup file.
add_shell_aliases() {
    print_info "Adding shell aliases..."
    append_login_rc "alias ll='ls -lah --color=auto'" '# aliases'
    append_login_rc "alias gs='git status'"
    append_login_rc "alias gp='git pull'"
    append_login_rc "alias dc='docker compose'"
}

# bash path: install the oh-my-posh prompt and wire it into ~/.bashrc.
section_bash_setup() {
    print_section "BASH PROMPT (oh-my-posh)"

    if sudo -Hu "$SUDO_USER" bash -c 'command -v oh-my-posh >/dev/null 2>&1 || [ -x "$HOME/.local/bin/oh-my-posh" ]'; then
        print_info "oh-my-posh already installed — skipping"
    else
        print_info "Installing oh-my-posh..."
        soft "oh-my-posh" sudo -Hu "$SUDO_USER" bash -c 'curl -s https://ohmyposh.dev/install.sh | bash -s'
    fi

    # oh-my-posh installs to ~/.local/bin and drops its themes in
    # ~/.cache/oh-my-posh/themes. Init it with the agnosterplus theme.
    append_bashrc 'command -v oh-my-posh >/dev/null 2>&1 && eval "$(oh-my-posh init bash --config $HOME/.cache/oh-my-posh/themes/agnosterplus.omp.json)"' '# oh-my-posh (prompt, agnosterplus theme)'

    print_success "oh-my-posh configured for bash (agnosterplus theme)"
    print_info "JetBrains Mono Nerd Font is installed — select it in your terminal so glyphs render."

    add_shell_aliases
}

section_shell_setup() {
    print_section "SHELL SETUP"

    # JetBrains Mono Nerd Font is installed for BOTH shells so the prompt
    # (powerlevel10k or oh-my-posh) always has its glyphs available, and set as
    # Konsole's default font so those glyphs actually render.
    install_nerd_font
    configure_konsole_font

    # Atuin: install now (bash hook wired by its own installer; zsh hook below).
    install_atuin

    # All bash rc-wiring lives here so there's one place that owns it. Added for
    # both shell choices so bash stays fully usable even when zsh is the default;
    # zsh gets its own inits further down. The zoxide/fzf PACKAGES are installed
    # in Section 2 (Core Software) — these are just their shell hooks.
    print_info "Wiring ~/.local/bin, zoxide and fzf into ~/.bashrc..."
    append_bashrc 'export PATH="$HOME/.local/bin:$PATH"' '# ~/.local/bin on PATH'
    append_bashrc 'command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"' '# zoxide (smarter cd)'
    append_bashrc 'command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)"' '# fzf (fuzzy finder)'

    if [[ "$SHELL_CHOICE" != "zsh" ]]; then
        section_bash_setup
        return 0
    fi

    print_section "ZSH + OH-MY-ZSH + POWERLEVEL10K"

    # zsh itself is installed in Section 2. Bail out gracefully if it's missing.
    if ! command -v zsh >/dev/null 2>&1; then
        WARNINGS+=("zsh setup (zsh binary not found)")
        print_warning "zsh is not installed — skipping zsh setup"
        return 0
    fi

    local ZDOTDIR_OMZ="$USER_HOME/.oh-my-zsh"
    local ZSH_CUSTOM="$ZDOTDIR_OMZ/custom"

    # ── oh-my-zsh (unattended: no chsh, no shell launch, writes a fresh .zshrc) ─
    if [[ -d "$ZDOTDIR_OMZ" ]]; then
        print_info "oh-my-zsh already installed — skipping installer"
    else
        print_info "Installing oh-my-zsh..."
        soft "oh-my-zsh" sudo -Hu "$SUDO_USER" bash -c \
            'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    fi

    # ── powerlevel10k theme ───────────────────────────────────────────────────
    if [[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
        print_info "powerlevel10k already present — skipping clone"
    else
        print_info "Installing powerlevel10k theme..."
        soft "powerlevel10k" sudo -Hu "$SUDO_USER" git clone --depth=1 \
            https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    fi

    # ── Autocomplete + syntax highlighting plugins ────────────────────────────
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
        soft "zsh-autosuggestions" sudo -Hu "$SUDO_USER" git clone --depth=1 \
            https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
        soft "zsh-syntax-highlighting" sudo -Hu "$SUDO_USER" git clone --depth=1 \
            https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi

    # ── Point .zshrc at powerlevel10k and enable the plugins ──────────────────
    # (syntax-highlighting must load last per its docs; fzf is a built-in
    #  oh-my-zsh plugin. zoxide is NOT — it's init'd explicitly below.)
    local ZSHRC="$USER_HOME/.zshrc"
    if [[ -f "$ZSHRC" ]]; then
        sudo -Hu "$SUDO_USER" sed -i \
            's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC"
        sudo -Hu "$SUDO_USER" sed -i \
            's|^plugins=.*|plugins=(git fzf zsh-autosuggestions zsh-syntax-highlighting)|' "$ZSHRC"
        print_success "Configured ~/.zshrc (theme + plugins)"
    else
        print_warning "~/.zshrc not found — oh-my-zsh install may have failed"
    fi

    # zsh doesn't add ~/.local/bin to PATH by default; do it before the
    # zoxide/atuin inits below, which look up those binaries.
    append_zshrc 'export PATH="$HOME/.local/bin:$PATH"' '# ~/.local/bin on PATH'

    # zoxide is not an oh-my-zsh plugin, so init it explicitly; fzf is (enabled
    # in the plugins list above) and needs no extra init.
    append_zshrc 'command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"' '# zoxide (smarter cd)'

    # Atuin for zsh (its installer targets bash; add the zsh hook too).
    append_zshrc 'command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"' '# atuin (shell history)'

    add_shell_aliases

    # ── Make zsh the default login shell for the user ─────────────────────────
    local zsh_path current_shell
    zsh_path="$(command -v zsh || true)"
    print_info "Setting zsh as the default shell for '$SUDO_USER'..."
    if [[ -z "$zsh_path" ]]; then
        WARNINGS+=("set zsh as default shell (zsh not found)")
        print_warning "zsh binary not found — cannot set it as the default shell."
    else
        # Register zsh in /etc/shells (chsh and some tools require it).
        if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
            echo "$zsh_path" >> /etc/shells
            print_info "Registered $zsh_path in /etc/shells"
        fi
        # Set the login shell in /etc/passwd. usermod (root, no PAM prompt) is
        # primary; fall back to chsh. '|| true' so set -e can't abort here.
        usermod -s "$zsh_path" "$SUDO_USER" 2>/dev/null \
            || chsh -s "$zsh_path" "$SUDO_USER" 2>/dev/null || true

        # Read back the source of truth from /etc/passwd and report it plainly.
        # Match on basename so /usr/bin/zsh vs /usr/sbin/zsh (same binary on
        # merged-/usr systems) both count as success.
        current_shell="$(getent passwd "$SUDO_USER" | cut -d: -f7)"
        if [[ "$(basename "$current_shell")" == "zsh" ]]; then
            print_success "Login shell for '$SUDO_USER' in /etc/passwd is now: $current_shell"
            print_warning "IMPORTANT: fully LOG OUT and back in (or reboot) for this to apply."
            print_warning "A new terminal tab in your CURRENT session may still start bash;"
            print_warning "verify with:  getent passwd $SUDO_USER   (7th field should end in /zsh)"
        else
            WARNINGS+=("set zsh as default shell (still '$current_shell')")
            print_warning "Login shell is still '$current_shell'. Set it manually with:"
            print_warning "    sudo chsh -s $zsh_path $SUDO_USER"
        fi
    fi

    print_success "zsh setup complete."
    print_info "On first launch, powerlevel10k runs its config wizard (or run 'p10k configure')."
}

################################################################################
#              SECTION 6: APPLICATIONS (ZED EDITOR + MULLVAD VPN)
#
#   Zed     — a fast, minimal code editor (official installer).
#   Mullvad — an open-source, privacy-focused VPN (official RPM repository).
################################################################################

# The desired Zed settings.json content, emitted to stdout. Kept in one place
# so the writer (below) and the summary printout use the exact same content.
zed_settings_content() {
    cat <<'ZED_SETTINGS'
// Zed settings
//
// For information on how to configure Zed, see the Zed
// documentation: https://zed.dev/docs/configuring-zed
//
// To see all of Zed's default settings without changing your
// custom settings, run `zed: open default settings` from the
// command palette (cmd-shift-p / ctrl-shift-p)
{
  "cli_default_open_behavior": "existing_window",
  "project_panel": {
    "dock": "left"
  },
  "outline_panel": {
    "dock": "left"
  },
  "collaboration_panel": {
    "dock": "left"
  },
  "agent": {
    "sidebar_side": "right",
    "dock": "right",
    "favorite_models": [],
    "model_parameters": []
  },
  "git_panel": {
    "dock": "left"
  },
  "telemetry": {
    "diagnostics": false,
    "metrics": false
  },
  "icon_theme": "Zed (Default)",
  "ui_font_size": 16,
  "buffer_font_size": 15,
  "theme": {
    "mode": "dark",
    "light": "One Light",
    "dark": "Ayu Dark"
  }
}
ZED_SETTINGS
}

# Write the Zed settings only if the user has none yet. If a settings.json
# already exists we never touch it — instead we flag it so section_summary
# prints the desired config for the user to copy manually.
apply_zed_settings() {
    local zed_dir="$USER_HOME/.config/zed"
    local zed_file="$zed_dir/settings.json"
    if [[ -f "$zed_file" ]]; then
        print_warning "Zed settings.json already exists — leaving it untouched."
        ZED_SETTINGS_NEEDS_MANUAL=true
        return 0
    fi
    install -d -o "$SUDO_USER" -g "$SUDO_USER" "$zed_dir"
    zed_settings_content | sudo -Hu "$SUDO_USER" tee "$zed_file" >/dev/null
    print_success "Wrote Zed settings to $zed_file"
}

section_apps() {
    print_section "ZED EDITOR"

    if sudo -Hu "$SUDO_USER" bash -c 'command -v zed >/dev/null 2>&1 || [ -x "$HOME/.local/bin/zed" ]'; then
        print_info "Zed already installed — skipping"
    else
        print_info "Installing Zed editor..."
        soft "Zed editor" sudo -Hu "$SUDO_USER" bash -c 'curl -fsSL https://zed.dev/install.sh | bash'
    fi

    apply_zed_settings

    print_section "MULLVAD VPN"

    print_info "Adding Mullvad repository..."
    dnf config-manager addrepo --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo --overwrite
    print_success "Mullvad repository added"

    print_info "Installing Mullvad VPN..."
    soft "Mullvad VPN" dnf install -y mullvad-vpn

    print_info "Official site: https://mullvad.net"
}

################################################################################
#              SECTION 7: ESSENTIAL DEV TOOLS   (installed in BOTH modes)
#
#   Host-level runtimes wanted regardless of containerization:
#     - Python 3 + pip
#     - Node LTS (via NVM) + npm
#     - Flutter + Dart  (kept host-side as a fallback if devcontainers fail)
################################################################################

section_dev_tools_essential() {
    print_section "ESSENTIAL DEV TOOLS"

     # ── Python3 + Pip ────────────────────────────────────────────────────────
    print_info "Installing Python 3 with development tools..."
    dnf install -y python3 python3-pip python3-devel
    print_success "Python 3 installed"

    print_info "Upgrading pip for user..."
    sudo -Hu "$SUDO_USER" python3 -m pip install --upgrade pip --user
    print_success "pip upgraded"

    print_info "Verifying Python installation..."
    python3 --version
    pip3 --version
    print_success "Python verified"

    # ── NVM + Node LTS ────────────────────────────────────────────────────────
    print_info "Installing NVM..."
    sudo -Hu "$SUDO_USER" bash -c \
        'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'
    print_success "NVM installed"

    # Make sure nvm loads in the shell(s) actually in use, whichever single
    # profile its installer happened to pick.
    ensure_nvm_rc "$USER_HOME/.bashrc"
    if [[ "$SHELL_CHOICE" == "zsh" ]]; then
        ensure_nvm_rc "$USER_HOME/.zshrc"
    fi

    print_info "Installing Node LTS via NVM..."
    sudo -Hu "$SUDO_USER" bash -c \
        'export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" &&
         nvm install --lts && nvm use --lts && nvm alias default node'
    print_success "Node LTS installed"

    # ── Flutter + Dart ────────────────────────────────────────────────────────
    # Flutter SDK bundles Dart — no separate Dart install needed.
    # Installed to ~/.flutter so everything lives under the user's home folder.
    print_info "Installing Flutter + Dart to $USER_HOME/.flutter..."
    FLUTTER_DIR="$USER_HOME/.flutter"
    if [[ -d "$FLUTTER_DIR/.git" ]]; then
        print_info "Flutter already present — pulling latest stable..."
        sudo -Hu "$SUDO_USER" git -C "$FLUTTER_DIR" fetch origin stable
        sudo -Hu "$SUDO_USER" git -C "$FLUTTER_DIR" checkout stable
        sudo -Hu "$SUDO_USER" git -C "$FLUTTER_DIR" pull --ff-only origin stable
    else
        sudo -Hu "$SUDO_USER" git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    fi

    # Add Flutter to PATH for the user's login shell(s) (bash, plus zsh if chosen).
    append_login_rc 'export PATH="$PATH:$HOME/.flutter/bin"' '# Flutter SDK'

    sudo -Hu "$SUDO_USER" bash -c "export PATH=\"\$PATH:$FLUTTER_DIR/bin\" && flutter precache"

    # Persist CHROME_EXECUTABLE so Flutter web finds Brave in future shells
    # (a bare `export` here would only live for the duration of this script).
    append_login_rc 'export CHROME_EXECUTABLE=/var/lib/flatpak/exports/bin/com.brave.Browser' '# Flutter: use Brave for web'

    print_success "Flutter + Dart installed and Brave set as CHROME_EXECUTABLE"
}

################################################################################
#              SECTION 8: OPTIONAL DEV TOOLS   (baremetal only)
#
#   Heavier / less-frequently-needed toolchains and local database services:
#     - Expo CLI (React Native; builds on the Node from Section 7)
#     - Go, Rustup
#     - Java 21 + Gradle + Spring Boot CLI (via SDKMAN), Maven
#     - PostgreSQL, MariaDB (local services)
#
#   SECURITY NOTE: Database services are configured for local development only.
#   Change default credentials before exposing to any network.
################################################################################

section_dev_tools_optional() {
    print_section "OPTIONAL DEV TOOLS"

    # ── React Native + Expo CLI ───────────────────────────────────────────────
    # Uses the Node LTS installed via NVM in Section 7 (Essential Dev Tools).
    print_info "Installing Expo CLI..."
    sudo -Hu "$SUDO_USER" bash -c \
        'export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" &&
         npm install -g @expo/cli'
    print_success "Expo CLI installed"

    # ── Go ────────────────────────────────────────────────────────────────────
    print_info "Installing Go..."
    dnf install -y golang
    # Without this, anything from `go install` lands in ~/go/bin unreachable.
    append_login_rc 'export PATH="$PATH:$HOME/go/bin"' '# Go binaries (go install)'
    print_success "Go installed"

    # ── Rustup ────────────────────────────────────────────────────────────────
    print_info "Installing Rustup..."
    if sudo -Hu "$SUDO_USER" bash -c 'command -v rustup >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/rustup" ]'; then
        print_info "Rustup already installed — running update instead"
        sudo -Hu "$SUDO_USER" bash -c 'source "$HOME/.cargo/env" 2>/dev/null; rustup update || true'
    else
        sudo -Hu "$SUDO_USER" bash -c \
            'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
    fi
    print_success "Rustup installed"

    # ── SDKMAN → Java 21, Gradle + Spring Boot CLI ───────────────────────────
    print_info "Installing SDKMAN..."
    if [[ -d "$USER_HOME/.sdkman" ]]; then
        print_info "SDKMAN already installed — skipping installer"
    else
        sudo -Hu "$SUDO_USER" bash -c 'curl -s "https://get.sdkman.io" | bash'
    fi
    # Resolve the newest 21.x "open" (OpenJDK) build from SDKMAN at runtime so
    # this never goes stale when SDKMAN rotates out an old patch release. Falls
    # back to a known-good pin if the API is unreachable.
    JAVA_VERSION=$(curl -s "https://api.sdkman.io/2/candidates/java/linuxx64/versions/list?installed=" 2>/dev/null \
        | grep -oE '21\.[0-9.]+-open' | sort -V | tail -1)
    if [[ -z "$JAVA_VERSION" ]]; then
        JAVA_VERSION="21.0.2-open"
        print_warning "Could not query SDKMAN for latest Java 21 — using fallback $JAVA_VERSION"
    fi
    print_info "Installing Java $JAVA_VERSION, Gradle, and Spring Boot CLI via SDKMAN..."
    soft "SDKMAN Java/Gradle/Spring Boot" sudo -Hu "$SUDO_USER" bash -c \
        'source "$HOME/.sdkman/bin/sdkman-init.sh" && \
         echo "n" | sdk install java '"$JAVA_VERSION"' && \
         sdk default java '"$JAVA_VERSION"' && \
         echo "n" | sdk install gradle && \
         echo "n" | sdk install springboot'

    # ── Make SDKMAN Java the system default; fall back to dnf only if it failed ──
    print_info "Setting SDKMAN Java as default system Java..."

    # SDKMAN installs to ~/.sdkman/candidates/java/<version> and creates a 'current' symlink
    SDKMAN_JAVA_PATH="$USER_HOME/.sdkman/candidates/java/current"

    if [[ -f "$SDKMAN_JAVA_PATH/bin/java" ]]; then
        # Register SDKMAN Java as the default alternative (priority 100)
        update-alternatives --install /usr/bin/java java "$SDKMAN_JAVA_PATH/bin/java" 100
        update-alternatives --install /usr/bin/javac javac "$SDKMAN_JAVA_PATH/bin/javac" 100
        update-alternatives --install /usr/bin/jar jar "$SDKMAN_JAVA_PATH/bin/jar" 100
        print_success "SDKMAN Java set as default system Java"
    else
        # SDKMAN install failed (already recorded in WARNINGS). No dnf fallback —
        # SDKMAN is the single source of truth for Java. Re-run to retry, or
        # install a JDK manually with: sdk install java
        print_warning "SDKMAN Java not found — no Java installed. Re-run to retry."
    fi

    # Maven is always installed via dnf (SDKMAN provides Gradle/Spring Boot, not Maven here).
    print_info "Installing Maven..."
    dnf install -y maven
    print_success "Maven installed"

    # ── PostgreSQL ────────────────────────────────────────────────────────────
    print_info "Installing PostgreSQL..."
    dnf install -y postgresql postgresql-server
    if [[ -f /var/lib/pgsql/data/PG_VERSION ]]; then
        print_info "PostgreSQL cluster already initialized — skipping initdb"
    else
        postgresql-setup --initdb
    fi
    systemctl enable postgresql
    soft "PostgreSQL service start" systemctl start postgresql

    # Account setup wrapped in a function so soft() can run it without set -e
    # aborting the whole section if the service above didn't come up.
    _pg_dev_account() {
        sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='dev'" | grep -q 1 || \
            sudo -u postgres psql -c "CREATE USER dev WITH PASSWORD 'dev';"
        sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='devdb'" | grep -q 1 || \
            sudo -u postgres psql -c "CREATE DATABASE devdb OWNER dev;"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE devdb TO dev;"
    }
    print_info "Creating PostgreSQL dev account (if missing)..."
    if _pg_dev_account; then
        print_success "PostgreSQL installed — user: dev, password: dev, db: devdb"
    else
        WARNINGS+=("PostgreSQL dev account setup")
        print_warning "PostgreSQL dev account setup failed (is the service running?)"
    fi

    # ── MariaDB ───────────────────────────────────────────────────────────────
    print_info "Installing MariaDB..."
    dnf install -y mariadb mariadb-server
    if [[ ! -d /var/lib/mysql/mysql ]]; then
        print_info "Initializing MariaDB data directory..."
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    fi
    systemctl enable mariadb
    systemctl start mariadb || true
    print_info "Waiting for MariaDB to be ready..."
    MARIADB_READY=false
    for i in $(seq 1 30); do
        if mysqladmin ping --silent 2>/dev/null; then
            MARIADB_READY=true
            break
        fi
        sleep 1
    done
    if [[ "$MARIADB_READY" == "true" ]]; then
        print_info "Creating MariaDB dev account (if missing)..."
        mysql -u root -e "CREATE USER IF NOT EXISTS 'dev'@'localhost' IDENTIFIED BY 'dev';"
        mysql -u root -e "CREATE DATABASE IF NOT EXISTS devdb;"
        mysql -u root -e "GRANT ALL PRIVILEGES ON devdb.* TO 'dev'@'localhost';"
        mysql -u root -e "FLUSH PRIVILEGES;"
        print_success "MariaDB installed — user: dev, password: dev, db: devdb"
    else
        print_warning "MariaDB did not become ready in time — skipping dev account setup"
        print_warning "Run 'sudo systemctl status mariadb' to diagnose"
    fi
}

################################################################################
#              SECTION 9: DOCKER & DOCKER COMPOSE
#
#   Installs Docker Engine from Docker's official RPM repository.
#   Includes: docker-ce, docker-ce-cli, containerd.io,
#             docker-buildx-plugin, docker-compose-plugin
#
#   SECURITY NOTE: Adding a user to the docker group grants privileges
#   equivalent to root. Only add trusted users. For production systems,
#   consider rootless Docker: https://docs.docker.com/engine/security/rootless/
################################################################################

section_docker() {
    print_section "DOCKER & DOCKER COMPOSE"

    # ── Remove any old/conflicting Docker packages ────────────────────────────
    print_info "Removing any conflicting legacy Docker packages..."
    dnf remove -y \
        docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-selinux \
        docker-engine-selinux \
        docker-engine 2>/dev/null || true
    print_success "Legacy packages removed (or were not present)"

    # ── Add Docker's official RPM repository ─────────────────────────────────
    print_info "Adding Docker's official RPM repository..."
    dnf config-manager addrepo \
        --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo --overwrite
    print_success "Docker repository added"

    # ── Install Docker Engine + Compose plugin ────────────────────────────────
    print_info "Installing Docker Engine, CLI, containerd, and plugins..."
    dnf install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    print_success "Docker installed"

    # ── Add user to docker group ──────────────────────────────────────────────
    print_warning "SECURITY: Adding '$SUDO_USER' to the docker group grants root-level privileges."
    print_warning "See: https://docs.docker.com/engine/install/linux-postinstall/"
    usermod -aG docker "$SUDO_USER"
    print_success "User '$SUDO_USER' added to docker group (takes effect after next login)"

    # ── Enable and start Docker daemon ────────────────────────────────────────
    print_info "Enabling and starting Docker daemon..."
    systemctl enable --now docker
    print_success "Docker daemon enabled and started"

    # ── Verify installation ───────────────────────────────────────────────────
    print_info "Verifying Docker installation..."
    docker --version
    docker compose version
    print_success "Docker verified"

    print_warning "Run 'newgrp docker' or log out and back in for group changes to take effect"
}

################################################################################
#              SECTION 10: SYSTEM CUSTOMIZATION
#
#   Sets hostname and performs final updates.
################################################################################

section_customization() {
    print_section "SYSTEM CUSTOMIZATION"

    CURRENT_HOSTNAME=$(hostnamectl --static 2>/dev/null || hostname)
    if [[ "$CURRENT_HOSTNAME" == "fedora-desktop" || "$CURRENT_HOSTNAME" == "fedora-laptop" ]]; then
        print_info "Hostname already set to '$CURRENT_HOSTNAME' — skipping hostname prompt"
    else
        # Interactive hostname selection menu
        print_info "Select your system type (for hostname):"
        echo "  1) fedora-desktop"
        echo "  2) fedora-laptop"
        read -p "Enter choice [1-2]: " HOSTNAME_CHOICE

        case $HOSTNAME_CHOICE in
            1)
                FINAL_HOSTNAME="fedora-desktop"
                ;;
            2)
                FINAL_HOSTNAME="fedora-laptop"
                ;;
            *)
                print_warning "Invalid choice. Using default: fedora-desktop"
                FINAL_HOSTNAME="fedora-desktop"
                ;;
        esac

        print_info "Setting hostname to: $FINAL_HOSTNAME"
        if hostnamectl set-hostname "$FINAL_HOSTNAME"; then
            print_success "Hostname set to: $FINAL_HOSTNAME"
        else
            print_error "Failed to set hostname. This may require reboot to take effect."
        fi
    fi

    print_info "Running final system updates..."
    dnf upgrade -y
    flatpak update -y
    print_success "System updated"
}

################################################################################
#              SECTION 11: DEV CONTAINERS
#
#   Scaffolds a reusable dev container template at
#   ~/.dotfiles/devcontainer-template/.devcontainer/ containing:
#     - devcontainer.json  (VS Code extensions, port forwarding, remoteUser)
#     - docker-compose.yml (app + PostgreSQL + MySQL + MongoDB)
#
#   No standalone devcontainer CLI is installed — container orchestration is
#   handled by your editor (Zed or VS Code "Reopen in Container").
#
#   To use the template in a project:
#     cp -r ~/.dotfiles/devcontainer-template/.devcontainer /path/to/your/project/
#   Then open the project in your editor and reopen in the container.
#
#   SECURITY NOTE: Database credentials are for LOCAL DEVELOPMENT ONLY.
#   Never use them in production or any network-exposed environment.
#
################################################################################

section_devcontainers() {
    print_section "DEV CONTAINERS"

    TEMPLATE_DIR="/home/$SUDO_USER/.dotfiles/devcontainer-template/.devcontainer"
    print_info "Creating template directory at $TEMPLATE_DIR..."
    mkdir -p "$TEMPLATE_DIR"

    # Deploy the dev container template from the repo's single source of truth
    # (devcontainer-template/.devcontainer) instead of embedding copies here,
    # so there is exactly one place to edit and no risk of the copies drifting.
    SRC_TEMPLATE="$SCRIPT_DIR/devcontainer-template/.devcontainer"
    if [[ -d "$SRC_TEMPLATE" ]]; then
        print_info "Copying dev container template from repo source..."
        cp -r "$SRC_TEMPLATE/." "$TEMPLATE_DIR/"
        print_success "Template files copied from $SRC_TEMPLATE"
    else
        WARNINGS+=("dev container template source not found ($SRC_TEMPLATE)")
        print_warning "Template source not found at $SRC_TEMPLATE — skipping template copy"
    fi

    chown -R "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.dotfiles"
    print_success "Ownership set for ~/.dotfiles"

    # ── Install the 'devinit' helper to ~/.local/bin ──────────────────────────
    # Ships next to this script at bin/devinit. Lets you scaffold .devcontainer/
    # into any project with a single command instead of copying by hand.
    print_info "Installing 'devinit' helper to ~/.local/bin..."
    USER_LOCAL_BIN="$USER_HOME/.local/bin"
    install -d -o "$SUDO_USER" -g "$SUDO_USER" "$USER_LOCAL_BIN"
    if [[ -f "$SCRIPT_DIR/bin/devinit" ]]; then
        install -m 0755 -o "$SUDO_USER" -g "$SUDO_USER" \
            "$SCRIPT_DIR/bin/devinit" "$USER_LOCAL_BIN/devinit"
        print_success "'devinit' installed to $USER_LOCAL_BIN/devinit"
    else
        WARNINGS+=("devinit helper (bin/devinit not found next to install.sh)")
        print_warning "bin/devinit not found at $SCRIPT_DIR/bin — skipping devinit install"
    fi

    print_info "Scaffold a project: cd into it and run 'devinit'"
    print_info "Then reopen the project in a container from your editor (Zed or VS Code)"
}

################################################################################
#              SECTION 12: INSTALLATION COMPLETE - SUMMARY
################################################################################

section_summary() {
    print_section "INSTALLATION COMPLETE"

    print_warning "Manual steps required after reboot:"
    echo ""
    echo "  [JetBrains Toolbox - manual install]"
    echo "    https://www.jetbrains.com/toolbox/"
    echo ""
    echo "  [Android Studio - manual install]"
    echo "    https://developer.android.com/studio"
    echo ""
    echo "  [SSH key for GitHub/GitLab]"
    echo "    ssh-keygen -t ed25519"
    echo "    cat ~/.ssh/id_ed25519.pub, then add it to GitHub/GitLab"
    echo ""

    # Report any non-critical steps that were skipped/failed during the run.
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        print_warning "${#WARNINGS[@]} optional step(s) were skipped or failed:"
        for w in "${WARNINGS[@]}"; do
            echo "    - $w"
        done
        echo ""
        print_info "Re-run the script to retry, or install these manually."
        echo ""
    else
        print_success "All steps completed with no skipped items."
    fi

    # If a Zed settings.json already existed, we didn't touch it — print the
    # desired config here so the user can copy whatever they want from it.
    if [[ "$ZED_SETTINGS_NEEDS_MANUAL" == "true" ]]; then
        print_warning "You already have ~/.config/zed/settings.json — it was left as-is."
        print_info "Desired Zed settings (copy any parts you want):"
        echo "----------------------------------------------------------------"
        zed_settings_content
        echo "----------------------------------------------------------------"
        echo ""
    fi

    print_success "Setup complete. Happy coding!"
}

################################################################################
#                         MAIN EXECUTION FLOW
################################################################################

main() {
    # parse_args first so --help works without sudo.
    parse_args "$@"
    print_info "Starting Fedora Developer Setup..."
    check_root
    select_mode
    select_shell

    # ── Base system, config, shell, apps (sections 1-6) — both modes ──────────
    section_system_updates        # Section 1
    section_core_software         # Section 2
    section_flatpak               # Section 3
    section_git_config            # Section 4
    section_shell_setup           # Section 5 (fonts, atuin, prompt; zsh optional)
    section_apps                  # Section 6 (Zed + Mullvad)

    # ── Essential dev tools (section 7) — both modes ──────────────────────────
    section_dev_tools_essential   # Section 7

    # ── Optional dev tools (section 8) — baremetal only ───────────────────────
    if [[ "$INSTALL_MODE" == "baremetal" ]]; then
        section_dev_tools_optional   # Section 8
    else
        print_info "Skipping optional dev tools (section 8) — devcontainer mode."
    fi

    # ── Docker + customization (sections 9-10) — both modes ───────────────────
    section_docker                # Section 9
    section_customization         # Section 10

    # ── Dev containers (section 11) ───────────────────────────────────────────
    # Always in devcontainer mode; opt-in for baremetal.
    if [[ "$INSTALL_MODE" == "devcontainer" || "$WITH_DEVCONTAINER" == "true" ]]; then
        section_devcontainers     # Section 11
    else
        print_info "Skipping dev containers (section 11)."
    fi

    section_summary               # Section 12
}

# Run main function
main "$@"
