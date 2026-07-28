#!/bin/bash

################################################################################
#                 DEBIAN / ARCH DEVELOPER SETUP SCRIPT
#
#   A cross-distro developer-workstation installer for the two non-Fedora
#   families. Fedora has its own closely-maintained script — use install.sh
#   there. This one is the "fun experiment" sibling.
#
#   Supported (auto-detected from /etc/os-release):
#     - Debian / Ubuntu  (apt)     — and derivatives (Mint, Pop!_OS, …)
#     - Arch / Manjaro   (pacman)  — bootstraps an AUR helper (yay)
#
#   Usage: chmod +x install-arch-debian.sh && sudo bash install-arch-debian.sh
#
#   Two install modes (selected at runtime, or via --mode flag):
#
#     1) devcontainer  Base system + shell + apps + Docker + ESSENTIAL dev
#                      tools (Python, Node, Flutter) + dev container template.
#                      Skips the OPTIONAL native toolchain (§8). Recommended.
#
#     2) baremetal     Everything above PLUS the optional native toolchain
#                      (Go, Rust, Java/Gradle, Expo, PostgreSQL, MariaDB).
#                      Optionally also scaffolds dev containers.
#
#   Optional --shell flag selects the default shell to set up:
#     --shell zsh    oh-my-zsh + powerlevel10k, set as the login shell
#     --shell bash   keep plain bash (default if not chosen interactively)
#
#   Non-interactive examples:
#     sudo bash install-arch-debian.sh --mode devcontainer --shell zsh
#     sudo bash install-arch-debian.sh --mode baremetal --with-devcontainer
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

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_info()    { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }

# Non-critical steps that may legitimately fail (a removed Flatpak ref, a
# transient network error, an unavailable package) are run through soft().
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

# Append a shell-agnostic env/PATH/alias line to the login shell(s) the user
# actually uses: always bash, plus zsh when zsh was selected. Use this for
# PATH/exports/aliases (valid in both shells) — NOT for shell-specific inits
# like `zoxide init bash` vs `zoxide init zsh`. Idempotent per file.
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
        print_error "This script must be run with sudo (e.g. 'sudo bash install-arch-debian.sh')"
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
#                   DISTRO DETECTION & PACKAGE ABSTRACTION
#
#   Everything distro-specific funnels through this layer so the section
#   functions below stay (mostly) family-agnostic:
#
#     DISTRO_FAMILY   normalized family: "debian" | "arch"
#     DISTRO_ID       raw ID (debian, ubuntu, arch, manjaro, …)
#     DEB_CODENAME    apt suite codename (debian/ubuntu only)
#     DEB_DOCKER_OS   "debian" or "ubuntu" for download.docker.com paths
#     AUR_HELPER      arch only: resolved AUR helper (yay/paru)
#     pkg_update / pkg_install / pkg_install_soft_batch / aur_install / run_user
################################################################################

DISTRO_ID=""
DISTRO_FAMILY=""
DEB_CODENAME=""
DEB_DOCKER_OS=""
AUR_HELPER=""

detect_distro() {
    if [[ ! -r /etc/os-release ]]; then
        print_error "/etc/os-release not found — cannot detect the distribution."
        exit 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-}"
    local like="${ID_LIKE:-}"

    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint|pop|elementary|zorin|kali|raspbian) DISTRO_FAMILY="debian" ;;
        arch|manjaro|endeavouros|cachyos|garuda|arcolinux)          DISTRO_FAMILY="arch" ;;
        fedora|rhel|centos|rocky|almalinux|nobara)
            print_error "This is a Fedora/RHEL system ($DISTRO_ID)."
            print_error "Use the dedicated Fedora script instead:  sudo bash install.sh"
            exit 1
            ;;
        *)
            if   [[ "$like" == *debian* || "$like" == *ubuntu* ]]; then DISTRO_FAMILY="debian"
            elif [[ "$like" == *arch* ]]; then DISTRO_FAMILY="arch"
            elif [[ "$like" == *rhel* || "$like" == *fedora* ]]; then
                print_error "This looks like a Fedora/RHEL system. Use: sudo bash install.sh"
                exit 1
            else
                print_error "Unsupported distribution: ${DISTRO_ID:-unknown} (ID_LIKE='$like')"
                print_error "This script supports Debian/Ubuntu and Arch families only."
                exit 1
            fi
            ;;
    esac

    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        # Prefer the Ubuntu codename on Ubuntu derivatives (Mint/Pop set their own).
        DEB_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
        if [[ "$like" == *ubuntu* || "$DISTRO_ID" == "ubuntu" ]]; then
            DEB_DOCKER_OS="ubuntu"
        else
            DEB_DOCKER_OS="debian"
            DEB_CODENAME="${VERSION_CODENAME:-$DEB_CODENAME}"
        fi
    fi

    print_info "Detected: ${PRETTY_NAME:-$DISTRO_ID}  →  family: $DISTRO_FAMILY"
    [[ "$DISTRO_FAMILY" == "debian" ]] && print_info "apt codename: ${DEB_CODENAME:-unknown}, docker OS path: $DEB_DOCKER_OS"
}

# Run a command as the invoking (non-root) user, with their environment/home.
run_user() { sudo -Hu "$SUDO_USER" "$@"; }

pkg_update() {
    case "$DISTRO_FAMILY" in
        debian) DEBIAN_FRONTEND=noninteractive apt-get update ;;
        arch)   pacman -Sy --noconfirm ;;
    esac
}

pkg_upgrade() {
    case "$DISTRO_FAMILY" in
        debian) DEBIAN_FRONTEND=noninteractive apt-get update && \
                DEBIAN_FRONTEND=noninteractive apt-get upgrade -y ;;
        arch)   pacman -Syu --noconfirm ;;
    esac
}

# Install packages (native names). Fails as a batch if any name is wrong.
pkg_install() {
    case "$DISTRO_FAMILY" in
        debian) DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" ;;
        arch)   pacman -S --needed --noconfirm "$@" ;;
    esac
}

# Try a batch install; if it fails (usually one unavailable name on this
# release), retry each package individually so the rest still get installed.
pkg_install_soft_batch() {
    if pkg_install "$@" 2>/dev/null; then
        return 0
    fi
    print_warning "Batch install failed — retrying packages individually..."
    local p
    for p in "$@"; do
        soft "package: $p" pkg_install "$p"
    done
}

# Arch-only: install from the AUR as the non-root user. Soft no-op elsewhere.
aur_install() {
    if [[ "$DISTRO_FAMILY" != "arch" ]]; then
        return 0
    fi
    if [[ -z "$AUR_HELPER" ]]; then
        print_warning "No AUR helper available — skipping AUR packages: $*"
        return 1
    fi
    run_user "$AUR_HELPER" -S --needed --noconfirm "$@"
}

# ── Cross-family package-name map ─────────────────────────────────────────────
PKG_BUILD=()     # C/C++ toolchain + dev headers
PKG_CLI=()       # core shell/CLI utilities (available in base repos)
PKG_MODERN=()    # nice-to-have modern CLI tools (best-effort)
PKG_DESKTOP=()   # desktop/gaming apps (best-effort)

map_packages() {
    case "$DISTRO_FAMILY" in
        debian)
            PKG_BUILD=(
                build-essential gcc g++ make cmake clang clang-tools ninja-build
                pkg-config libgtk-3-dev libxss-dev libxtst-dev
                libgl1-mesa-dev libglu1-mesa libxrandr-dev libxcursor-dev
                libsecret-1-dev libx11-dev libxrender-dev libcurl4-openssl-dev
                unzip xz-utils zip ca-certificates gnupg lsb-release
            )
            PKG_CLI=(
                git git-lfs curl wget jq ripgrep fd-find fzf zoxide bat
                htop tmux zsh fontconfig
            )
            # gh comes from its own apt repo (added in section_core_software).
            PKG_MODERN=( btop fastfetch eza git-delta )   # not all in Debian stable
            PKG_DESKTOP=( steam-installer gnome-disk-utility mangohud goverlay )
            ;;
        arch)
            PKG_BUILD=(
                base-devel cmake clang ninja
                gtk3 libxss libxtst mesa glu libxrandr libxcursor
                libsecret libx11 libxrender curl
                unzip xz zip
            )
            PKG_CLI=(
                git git-lfs curl wget jq ripgrep fd fzf zoxide bat
                htop tmux zsh github-cli fontconfig
            )
            PKG_MODERN=( btop fastfetch eza git-delta lazygit tealdeer )
            PKG_DESKTOP=( steam gnome-disk-utility mangohud goverlay )
            ;;
    esac
}

################################################################################
#                         INSTALL MODE SELECTION
################################################################################

INSTALL_MODE=""          # "baremetal" or "devcontainer"
WITH_DEVCONTAINER=false  # baremetal-only: also run the dev container section
SHELL_CHOICE=""          # "zsh" or "bash" (default shell to set up)
ZED_SETTINGS_NEEDS_MANUAL=false  # set true when a Zed settings.json already exists

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)  INSTALL_MODE="${2:-}"; shift 2 ;;
            --mode=*) INSTALL_MODE="${1#*=}"; shift ;;
            --with-devcontainer) WITH_DEVCONTAINER=true; shift ;;
            --shell) SHELL_CHOICE="${2:-}"; shift 2 ;;
            --shell=*) SHELL_CHOICE="${1#*=}"; shift ;;
            # Print the banner: skip the shebang, strip the leading '#' from
            # comment lines, and stop at the first line of actual code.
            -h|--help) awk 'NR==1{next} /^#/{sub(/^#/,""); print; next} /^[[:space:]]*$/{next} {exit}' "$0"; exit 0 ;;
            *) print_error "Unknown argument: $1"; exit 1 ;;
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

    if [[ "$INSTALL_MODE" == "baremetal" && "$WITH_DEVCONTAINER" == "false" ]]; then
        read -p "Also set up dev containers (template + devinit)? [y/N]: " DC_CHOICE
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
#              SECTION 1: SYSTEM UPDATES & REPOS
#
#   Debian/Ubuntu: enable contrib/non-free (Debian) or universe/multiverse
#                  (Ubuntu) so Steam, mangohud, etc. are installable.
#   Arch:          enable the [multilib] repo (needed for Steam), refresh.
################################################################################

section_system_updates() {
    print_section "SYSTEM UPDATES & REPOS"

    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        print_info "Refreshing apt and enabling extra components..."
        pkg_update
        # software-properties-common provides add-apt-repository.
        soft "software-properties-common" pkg_install software-properties-common apt-transport-https
        if [[ "$DEB_DOCKER_OS" == "ubuntu" ]]; then
            soft "enable universe/multiverse" add-apt-repository -y universe
            soft "enable multiverse" add-apt-repository -y multiverse
        else
            soft "enable contrib" add-apt-repository -y contrib
            soft "enable non-free" add-apt-repository -y non-free
            soft "enable non-free-firmware" add-apt-repository -y non-free-firmware
        fi
        # 32-bit (i386) multiarch is required for Steam and many game libraries.
        print_info "Enabling i386 multiarch (needed for Steam)..."
        soft "add i386 architecture" dpkg --add-architecture i386
        pkg_update
        print_info "Upgrading installed packages..."
        soft "system upgrade" bash -c 'DEBIAN_FRONTEND=noninteractive apt-get upgrade -y'

    elif [[ "$DISTRO_FAMILY" == "arch" ]]; then
        print_info "Enabling the [multilib] repository (for Steam and 32-bit libs)..."
        # Uncomment the [multilib] section in /etc/pacman.conf if still commented.
        if grep -q '^\s*#\s*\[multilib\]' /etc/pacman.conf; then
            # Uncomment the [multilib] header and the Include line that follows it.
            sed -i '/^\s*#\s*\[multilib\]/{s/^\s*#\s*//; n; s/^\s*#\s*//}' /etc/pacman.conf
            print_success "[multilib] enabled in /etc/pacman.conf"
        else
            print_info "[multilib] already enabled (or not commented) — leaving as-is"
        fi
        print_info "Synchronizing and upgrading the system..."
        pkg_upgrade
    fi

    print_success "System updated"
}

################################################################################
#              SECTION 2: CORE SOFTWARE
#
#   Build/CLI toolchain plus the desktop essentials this personal machine is
#   built around (steam, mangohud, goverlay, etc.). Shell integration for the
#   CLI tools installed here is wired up later in Section 5 (Shell Setup).
################################################################################

# Arch only: make sure an AUR helper exists (build yay from source if needed).
ensure_aur_helper() {
    [[ "$DISTRO_FAMILY" == "arch" ]] || return 0

    local h
    for h in yay paru; do
        if run_user bash -c "command -v $h >/dev/null 2>&1"; then
            AUR_HELPER="$h"
            print_info "AUR helper found: $AUR_HELPER"
            return 0
        fi
    done

    print_info "No AUR helper found — bootstrapping 'yay' from the AUR..."
    pkg_install base-devel git
    local tmp
    tmp=$(run_user mktemp -d)
    if run_user git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp/yay" \
        && run_user bash -c "cd '$tmp/yay' && makepkg -s --noconfirm" \
        && pacman -U --noconfirm "$tmp"/yay/*.pkg.tar.zst; then
        AUR_HELPER="yay"
        print_success "yay installed"
    else
        WARNINGS+=("AUR helper bootstrap (yay)")
        print_warning "Could not build yay — AUR packages (e.g. Mullvad) will be skipped."
    fi
    rm -rf "$tmp" 2>/dev/null || true
}

section_core_software() {
    print_section "CORE SOFTWARE"

    ensure_aur_helper

    print_info "Installing build toolchain and core CLI tools..."
    pkg_install_soft_batch "${PKG_BUILD[@]}" "${PKG_CLI[@]}"

    # ── GitHub CLI (gh) ───────────────────────────────────────────────────────
    # Not in Debian/Ubuntu base repos — add GitHub's apt repo. On Arch it's the
    # 'github-cli' package installed above.
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        print_info "Adding the GitHub CLI apt repository..."
        install -d -m 0755 /etc/apt/keyrings
        if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; then
            chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                > /etc/apt/sources.list.d/github-cli.list
            pkg_update
            soft "GitHub CLI (gh)" pkg_install gh
        else
            WARNINGS+=("GitHub CLI repo key")
            print_warning "Could not fetch gh repo key — skipping gh"
        fi
    fi

    print_info "Initializing Git LFS..."
    soft "git lfs install" run_user git lfs install

    # ── Modern CLI tools (best-effort) ────────────────────────────────────────
    print_info "Installing modern CLI tools (best-effort)..."
    local tool
    for tool in "${PKG_MODERN[@]}"; do
        print_info "  → $tool"
        soft "CLI tool: $tool" pkg_install "$tool"
    done

    # ── Desktop / gaming apps (best-effort) ───────────────────────────────────
    # Steam pulls i386 (Debian) / multilib (Arch) deps enabled in section 1.
    print_info "Installing desktop/gaming apps (best-effort)..."
    local dapp
    for dapp in "${PKG_DESKTOP[@]}"; do
        print_info "  → $dapp"
        soft "desktop app: $dapp" pkg_install "$dapp"
    done

    print_success "Core software processed"
}

################################################################################
#              SECTION 3: FLATPAK & FLATHUB SETUP
################################################################################

section_flatpak() {
    print_section "FLATPAK & FLATHUB SETUP"

    print_info "Ensuring Flatpak is installed..."
    soft "flatpak" pkg_install flatpak

    if ! command -v flatpak >/dev/null 2>&1; then
        WARNINGS+=("Flatpak not available — skipping Flatpak apps")
        print_warning "Flatpak did not install — skipping this section"
        return 0
    fi

    print_info "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    print_success "Flathub added"

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

################################################################################
#              SECTION 4: GIT CONFIGURATION
################################################################################

section_git_config() {
    print_section "GIT CONFIGURATION"

    print_info "Configuring Git..."
    run_user git config --global user.name "$GIT_USERNAME"
    run_user git config --global user.email "$GIT_EMAIL"
    run_user git config --global pull.rebase false
    run_user git config --global init.defaultBranch main
    # Set the upstream automatically on first push of a new branch.
    run_user git config --global push.autoSetupRemote true
    # Normalize line endings to LF on commit (correct for Linux/macOS).
    run_user git config --global core.autocrlf input
    print_success "Git configured"

    print_info "Adding Git aliases (lg, st, undo)..."
    run_user git config --global alias.lg "log --oneline --graph --decorate --all"
    run_user git config --global alias.st "status -sb"
    run_user git config --global alias.undo "reset --soft HEAD~1"
    print_success "Git aliases configured"

    run_user git config --global --list | grep -E "user\.|pull\.|init\." || true
}

################################################################################
#              SECTION 5: SHELL SETUP
#
#   The single home for everything that writes to ~/.bashrc / ~/.zshrc:
#     - JetBrains Mono Nerd Font + Konsole default font
#     - ~/.local/bin on PATH, zoxide + fzf + atuin hooks (+ Debian bat/fd aliases)
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
    [[ -n "$kread" ]] && default_profile=$(run_user "$kread" \
        --file konsolerc --group "Desktop Entry" --key DefaultProfile 2>/dev/null || true)

    if [[ -n "$default_profile" && -f "$kdir/$default_profile" ]]; then
        profile_file="$kdir/$default_profile"
        print_info "Updating Konsole font in existing profile: $default_profile"
    else
        profile_file="$kdir/Dotfiles.profile"
        run_user "$kwrite" --file "$profile_file" --group General --key Name "Dotfiles" || true
        run_user "$kwrite" --file konsolerc --group "Desktop Entry" --key DefaultProfile "Dotfiles.profile" || true
        print_info "Created Konsole profile 'Dotfiles' and set it as default"
    fi

    soft "Konsole font (kwriteconfig)" run_user "$kwrite" \
        --file "$profile_file" --group Appearance --key Font "$font"
    print_success "Konsole default font set to JetBrainsMono Nerd Font (restart Konsole to apply)"
}

# Atuin (shell history). Installed here so its install and shell hooks live in
# one section. Its own installer wires the bash hook into ~/.bashrc; the zsh
# hook is added in section_shell_setup's zsh branch.
install_atuin() {
    print_section "ATUIN SHELL HISTORY MANAGER"

    if run_user bash -c 'command -v atuin >/dev/null 2>&1 || [ -x "$HOME/.local/bin/atuin" ] || [ -x "$HOME/.atuin/bin/atuin" ]'; then
        print_info "Atuin already installed — skipping"
    else
        print_info "Installing Atuin shell history manager (non-interactive)..."
        soft "Atuin" run_user bash -c 'curl --proto "=https" --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive'
    fi
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

    if run_user bash -c 'command -v oh-my-posh >/dev/null 2>&1 || [ -x "$HOME/.local/bin/oh-my-posh" ]'; then
        print_info "oh-my-posh already installed — skipping"
    else
        print_info "Installing oh-my-posh..."
        soft "oh-my-posh" run_user bash -c 'curl -s https://ohmyposh.dev/install.sh | bash -s'
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
    # Debian ships fzf's key bindings as a file; fall back to `fzf --bash`.
    append_bashrc '[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash; command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash 2>/dev/null)" 2>/dev/null' '# fzf (fuzzy finder)'
    # Debian names the binaries batcat / fdfind — add friendly aliases (bash).
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        append_bashrc 'command -v batcat >/dev/null 2>&1 && alias bat=batcat' '# bat alias (Debian names it batcat)'
        append_bashrc 'command -v fdfind >/dev/null 2>&1 && alias fd=fdfind' '# fd alias (Debian names it fdfind)'
    fi

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
        soft "oh-my-zsh" run_user bash -c \
            'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    fi

    # ── powerlevel10k theme ───────────────────────────────────────────────────
    if [[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
        print_info "powerlevel10k already present — skipping clone"
    else
        print_info "Installing powerlevel10k theme..."
        soft "powerlevel10k" run_user git clone --depth=1 \
            https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    fi

    # ── Autocomplete + syntax highlighting plugins ────────────────────────────
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
        soft "zsh-autosuggestions" run_user git clone --depth=1 \
            https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
        soft "zsh-syntax-highlighting" run_user git clone --depth=1 \
            https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi

    # ── Point .zshrc at powerlevel10k and enable the plugins ──────────────────
    # (syntax-highlighting must load last per its docs; fzf is a built-in
    #  oh-my-zsh plugin. zoxide is NOT — it's init'd explicitly below.)
    local ZSHRC="$USER_HOME/.zshrc"
    if [[ -f "$ZSHRC" ]]; then
        run_user sed -i \
            's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC"
        run_user sed -i \
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

    # Debian bat/fd aliases for zsh as well (batcat/fdfind naming).
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        append_zshrc 'command -v batcat >/dev/null 2>&1 && alias bat=batcat' '# bat alias (Debian names it batcat)'
        append_zshrc 'command -v fdfind >/dev/null 2>&1 && alias fd=fdfind' '# fd alias (Debian names it fdfind)'
    fi

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
#   Zed     — a fast, minimal code editor (official, distro-agnostic installer).
#   Mullvad — Debian/Ubuntu: official apt repo; Arch: 'mullvad-vpn-bin' (AUR).
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
    zed_settings_content | run_user tee "$zed_file" >/dev/null
    print_success "Wrote Zed settings to $zed_file"
}

section_apps() {
    print_section "ZED EDITOR"

    if run_user bash -c 'command -v zed >/dev/null 2>&1 || [ -x "$HOME/.local/bin/zed" ]'; then
        print_info "Zed already installed — skipping"
    else
        print_info "Installing Zed editor..."
        soft "Zed editor" run_user bash -c 'curl -fsSL https://zed.dev/install.sh | bash'
    fi

    apply_zed_settings

    print_section "MULLVAD VPN"

    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        print_info "Adding the Mullvad apt repository..."
        install -d -m 0755 /usr/share/keyrings
        if curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc \
                https://repository.mullvad.net/deb/mullvad-keyring.asc; then
            echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$(dpkg --print-architecture)] https://repository.mullvad.net/deb/stable $(lsb_release -cs 2>/dev/null || echo stable) main" \
                > /etc/apt/sources.list.d/mullvad.list
            pkg_update
            soft "Mullvad VPN" pkg_install mullvad-vpn
        else
            WARNINGS+=("Mullvad repo key")
            print_warning "Could not fetch Mullvad repo key — skipping"
        fi
    elif [[ "$DISTRO_FAMILY" == "arch" ]]; then
        print_info "Installing Mullvad VPN from the AUR (mullvad-vpn-bin)..."
        soft "Mullvad VPN (AUR)" aur_install mullvad-vpn-bin
    fi

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

    # ── Python 3 + pip ────────────────────────────────────────────────────────
    print_info "Installing Python 3..."
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        pkg_install_soft_batch python3 python3-pip python3-venv python3-dev pipx
    else
        pkg_install_soft_batch python python-pip python-pipx
    fi
    print_success "Python 3 installed"
    run_user python3 --version || true

    # ── NVM + Node LTS ────────────────────────────────────────────────────────
    print_info "Installing NVM..."
    soft "NVM" run_user bash -c \
        'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'

    # Make sure nvm loads in the shell(s) actually in use, whichever single
    # profile its installer happened to pick.
    ensure_nvm_rc "$USER_HOME/.bashrc"
    if [[ "$SHELL_CHOICE" == "zsh" ]]; then
        ensure_nvm_rc "$USER_HOME/.zshrc"
    fi

    print_info "Installing Node LTS via NVM..."
    soft "Node LTS" run_user bash -c \
        'export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" &&
         nvm install --lts && nvm use --lts && nvm alias default node'

    # ── Flutter + Dart ────────────────────────────────────────────────────────
    print_info "Installing Flutter + Dart to $USER_HOME/.flutter..."
    FLUTTER_DIR="$USER_HOME/.flutter"
    if [[ -d "$FLUTTER_DIR/.git" ]]; then
        print_info "Flutter already present — pulling latest stable..."
        run_user git -C "$FLUTTER_DIR" fetch origin stable || true
        run_user git -C "$FLUTTER_DIR" checkout stable || true
        run_user git -C "$FLUTTER_DIR" pull --ff-only origin stable || true
    else
        soft "Flutter clone" run_user git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    fi
    # Add Flutter to PATH for the user's login shell(s) (bash, plus zsh if chosen).
    append_login_rc 'export PATH="$PATH:$HOME/.flutter/bin"' '# Flutter SDK'
    soft "Flutter precache" run_user bash -c "export PATH=\"\$PATH:$FLUTTER_DIR/bin\" && flutter precache"
    append_login_rc 'export CHROME_EXECUTABLE=/var/lib/flatpak/exports/bin/com.brave.Browser' '# Flutter: use Brave for web'

    print_success "Essential dev tools installed"
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
#   SECURITY NOTE: Database services are configured for LOCAL development only.
################################################################################

section_dev_tools_optional() {
    print_section "OPTIONAL DEV TOOLS"

    # ── React Native + Expo CLI ───────────────────────────────────────────────
    # Uses the Node LTS installed via NVM in Section 7 (Essential Dev Tools).
    print_info "Installing Expo CLI..."
    soft "Expo CLI" run_user bash -c \
        'export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && npm install -g @expo/cli'

    # ── Go ────────────────────────────────────────────────────────────────────
    print_info "Installing Go..."
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        soft "Go" pkg_install golang-go
    else
        soft "Go" pkg_install go
    fi
    # Without this, anything from `go install` lands in ~/go/bin unreachable.
    append_login_rc 'export PATH="$PATH:$HOME/go/bin"' '# Go binaries (go install)'

    # ── Rustup ────────────────────────────────────────────────────────────────
    print_info "Installing Rustup..."
    if run_user bash -c 'command -v rustup >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/rustup" ]'; then
        print_info "Rustup already installed — updating"
        run_user bash -c 'source "$HOME/.cargo/env" 2>/dev/null; rustup update || true'
    else
        soft "Rustup" run_user bash -c \
            'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
    fi

    # ── SDKMAN → Java 21, Gradle, Spring Boot CLI ─────────────────────────────
    print_info "Installing SDKMAN..."
    if [[ -d "$USER_HOME/.sdkman" ]]; then
        print_info "SDKMAN already installed — skipping installer"
    else
        # zip/unzip/curl are required by SDKMAN (installed in section 2).
        soft "SDKMAN" run_user bash -c 'curl -s "https://get.sdkman.io" | bash'
    fi
    JAVA_VERSION=$(curl -s "https://api.sdkman.io/2/candidates/java/linuxx64/versions/list?installed=" 2>/dev/null \
        | grep -oE '21\.[0-9.]+-open' | sort -V | tail -1)
    if [[ -z "$JAVA_VERSION" ]]; then
        JAVA_VERSION="21.0.2-open"
        print_warning "Could not query SDKMAN for latest Java 21 — using fallback $JAVA_VERSION"
    fi
    print_info "Installing Java $JAVA_VERSION, Gradle, and Spring Boot CLI via SDKMAN..."
    soft "SDKMAN Java/Gradle/Spring Boot" run_user bash -c \
        'source "$HOME/.sdkman/bin/sdkman-init.sh" && \
         echo "n" | sdk install java '"$JAVA_VERSION"' && \
         sdk default java '"$JAVA_VERSION"' && \
         echo "n" | sdk install gradle && \
         echo "n" | sdk install springboot'

    # Maven from the distro repo (SDKMAN provides Gradle/Spring Boot, not Maven).
    print_info "Installing Maven..."
    soft "Maven" pkg_install maven

    # ── PostgreSQL ────────────────────────────────────────────────────────────
    print_info "Installing PostgreSQL..."
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        # Debian/Ubuntu auto-create a cluster and enable the service on install.
        soft "PostgreSQL" pkg_install postgresql postgresql-contrib
    else
        soft "PostgreSQL" pkg_install postgresql
        # Arch does NOT initialize a cluster — do it as the postgres user.
        if [[ ! -f /var/lib/postgres/data/PG_VERSION ]]; then
            print_info "Initializing PostgreSQL data directory (Arch)..."
            soft "PostgreSQL initdb" sudo -u postgres initdb -D /var/lib/postgres/data --locale=C.UTF-8 -E UTF8
        fi
    fi
    soft "enable postgresql" systemctl enable postgresql
    soft "start postgresql" systemctl start postgresql

    _pg_dev_account() {
        sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='dev'" | grep -q 1 || \
            sudo -u postgres psql -c "CREATE USER dev WITH PASSWORD 'dev';"
        sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='devdb'" | grep -q 1 || \
            sudo -u postgres psql -c "CREATE DATABASE devdb OWNER dev;"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE devdb TO dev;"
    }
    print_info "Creating PostgreSQL dev account (if missing)..."
    if _pg_dev_account; then
        print_success "PostgreSQL — user: dev, password: dev, db: devdb"
    else
        WARNINGS+=("PostgreSQL dev account setup")
        print_warning "PostgreSQL dev account setup failed (is the service running?)"
    fi

    # ── MariaDB ───────────────────────────────────────────────────────────────
    print_info "Installing MariaDB..."
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        soft "MariaDB" pkg_install mariadb-server
    else
        soft "MariaDB" pkg_install mariadb
        if [[ ! -d /var/lib/mysql/mysql ]]; then
            print_info "Initializing MariaDB data directory (Arch)..."
            soft "MariaDB install-db" mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
        fi
    fi
    soft "enable mariadb" systemctl enable mariadb
    soft "start mariadb" systemctl start mariadb
    print_info "Waiting for MariaDB to be ready..."
    MARIADB_READY=false
    for i in $(seq 1 30); do
        if mysqladmin ping --silent 2>/dev/null; then MARIADB_READY=true; break; fi
        sleep 1
    done
    if [[ "$MARIADB_READY" == "true" ]]; then
        print_info "Creating MariaDB dev account (if missing)..."
        mysql -u root -e "CREATE USER IF NOT EXISTS 'dev'@'localhost' IDENTIFIED BY 'dev';"
        mysql -u root -e "CREATE DATABASE IF NOT EXISTS devdb;"
        mysql -u root -e "GRANT ALL PRIVILEGES ON devdb.* TO 'dev'@'localhost';"
        mysql -u root -e "FLUSH PRIVILEGES;"
        print_success "MariaDB — user: dev, password: dev, db: devdb"
    else
        WARNINGS+=("MariaDB dev account setup")
        print_warning "MariaDB did not become ready in time — skipping dev account setup"
    fi
}

################################################################################
#              SECTION 9: DOCKER & DOCKER COMPOSE
#
#   Debian/Ubuntu: Docker's official apt repository.
#   Arch:          docker + docker-compose + docker-buildx from the repos.
#
#   SECURITY NOTE: Adding a user to the docker group grants root-equivalent
#   privileges. See https://docs.docker.com/engine/security/rootless/
################################################################################

section_docker() {
    print_section "DOCKER & DOCKER COMPOSE"

    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        print_info "Removing any conflicting distro Docker packages..."
        DEBIAN_FRONTEND=noninteractive apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc 2>/dev/null || true

        print_info "Adding Docker's official apt repository ($DEB_DOCKER_OS/$DEB_CODENAME)..."
        install -d -m 0755 /etc/apt/keyrings
        curl -fsSL "https://download.docker.com/linux/$DEB_DOCKER_OS/gpg" -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$DEB_DOCKER_OS $DEB_CODENAME stable" \
            > /etc/apt/sources.list.d/docker.list
        pkg_update
        print_info "Installing Docker Engine, CLI, containerd, and plugins..."
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    elif [[ "$DISTRO_FAMILY" == "arch" ]]; then
        print_info "Installing Docker from the Arch repositories..."
        pkg_install docker docker-compose docker-buildx
    fi
    print_success "Docker installed"

    print_warning "SECURITY: Adding '$SUDO_USER' to the docker group grants root-level privileges."
    usermod -aG docker "$SUDO_USER"
    print_success "User '$SUDO_USER' added to docker group (takes effect after next login)"

    print_info "Enabling and starting the Docker daemon..."
    soft "enable docker" systemctl enable --now docker

    print_info "Verifying Docker installation..."
    docker --version || true
    docker compose version || true
    print_warning "Run 'newgrp docker' or log out/in for group changes to take effect"
}

################################################################################
#              SECTION 10: SYSTEM CUSTOMIZATION
#
#   Sets a distro-aware hostname (<distro>-<chassis>) and runs final updates.
################################################################################

# Best-effort desktop/laptop detection.
detect_chassis() {
    local c=""
    c=$(hostnamectl chassis 2>/dev/null) || c=""
    if [[ -z "$c" && -r /sys/class/dmi/id/chassis_type ]]; then
        case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" in
            8|9|10|11|14|30|31|32) c="laptop" ;;
            *)                     c="desktop" ;;
        esac
    fi
    case "$c" in
        laptop|notebook|handset|tablet|convertible) echo "laptop" ;;
        *)                                           echo "desktop" ;;
    esac
}

section_customization() {
    print_section "SYSTEM CUSTOMIZATION"

    local prefix chassis suggested
    prefix="$DISTRO_ID"                       # e.g. debian, ubuntu, arch, manjaro
    chassis="$(detect_chassis)"               # laptop | desktop
    suggested="${prefix}-${chassis}"

    CURRENT_HOSTNAME=$(hostnamectl --static 2>/dev/null || hostname)
    if [[ "$CURRENT_HOSTNAME" == "$prefix-desktop" || "$CURRENT_HOSTNAME" == "$prefix-laptop" ]]; then
        print_info "Hostname already set to '$CURRENT_HOSTNAME' — skipping"
    else
        print_info "Suggested hostname (auto-detected): $suggested"
        echo "  1) $prefix-desktop"
        echo "  2) $prefix-laptop"
        read -p "Enter choice [1-2, default: $([[ "$chassis" == "laptop" ]] && echo 2 || echo 1)]: " HOSTNAME_CHOICE
        case "$HOSTNAME_CHOICE" in
            1) FINAL_HOSTNAME="$prefix-desktop" ;;
            2) FINAL_HOSTNAME="$prefix-laptop" ;;
            "") FINAL_HOSTNAME="$suggested" ;;
            *) print_warning "Invalid choice — using detected default: $suggested"
               FINAL_HOSTNAME="$suggested" ;;
        esac
        print_info "Setting hostname to: $FINAL_HOSTNAME"
        if hostnamectl set-hostname "$FINAL_HOSTNAME"; then
            print_success "Hostname set to: $FINAL_HOSTNAME"
        else
            print_error "Failed to set hostname (may require reboot)."
        fi
    fi

    print_info "Running final system updates..."
    soft "final system upgrade" pkg_upgrade
    command -v flatpak >/dev/null 2>&1 && soft "flatpak update" flatpak update -y
    print_success "System updated"
}

################################################################################
#              SECTION 11: DEV CONTAINERS
#
#   Scaffolds the reusable dev container template at
#   ~/.dotfiles/devcontainer-template/.devcontainer/ and installs the 'devinit'
#   helper. Identical to the Fedora script's template (kept in sync by hand).
#
#   SECURITY NOTE: Database credentials are for LOCAL DEVELOPMENT ONLY.
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
    print_info "Installing 'devinit' helper to ~/.local/bin..."
    USER_LOCAL_BIN="$USER_HOME/.local/bin"
    install -d -o "$SUDO_USER" -g "$SUDO_USER" "$USER_LOCAL_BIN"
    if [[ -f "$SCRIPT_DIR/bin/devinit" ]]; then
        install -m 0755 -o "$SUDO_USER" -g "$SUDO_USER" \
            "$SCRIPT_DIR/bin/devinit" "$USER_LOCAL_BIN/devinit"
        print_success "'devinit' installed to $USER_LOCAL_BIN/devinit"
    else
        WARNINGS+=("devinit helper (bin/devinit not found next to this script)")
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

    print_warning "Manual steps you may still want:"
    echo ""
    echo "  [JetBrains Toolbox]   https://www.jetbrains.com/toolbox/"
    echo "  [Android Studio]      https://developer.android.com/studio"
    echo "  [SSH key for GitHub]  ssh-keygen -t ed25519"
    echo "                        then add ~/.ssh/id_ed25519.pub to GitHub/GitLab"
    echo ""

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        print_warning "${#WARNINGS[@]} optional step(s) were skipped or failed:"
        for w in "${WARNINGS[@]}"; do echo "    - $w"; done
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
    print_info "Starting Debian/Arch Developer Setup..."
    check_root
    detect_distro
    map_packages
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
    if [[ "$INSTALL_MODE" == "devcontainer" || "$WITH_DEVCONTAINER" == "true" ]]; then
        section_devcontainers     # Section 11
    else
        print_info "Skipping dev containers (section 11)."
    fi

    section_summary               # Section 12
}

main "$@"
