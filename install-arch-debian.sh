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
#     1) devcontainer  Base system + Docker + dev container tooling only.
#                      No native dev runtimes on the host. (Recommended)
#
#     2) baremetal     Full host toolchain (languages, runtimes, local DBs).
#                      Optionally also sets up dev containers.
#
#   Non-interactive examples:
#     sudo bash install-arch-debian.sh --mode devcontainer
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
                htop tmux zsh
            )
            # gh comes from its own apt repo (added in section_build_tools).
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
                htop tmux zsh github-cli
            )
            PKG_MODERN=( btop fastfetch eza git-delta lazygit tealdeer starship )
            PKG_DESKTOP=( steam gnome-disk-utility mangohud goverlay )
            ;;
    esac
}

################################################################################
#                         INSTALL MODE SELECTION
################################################################################

INSTALL_MODE=""          # "baremetal" or "devcontainer"
WITH_DEVCONTAINER=false  # baremetal-only: also run the dev container section

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)  INSTALL_MODE="${2:-}"; shift 2 ;;
            --mode=*) INSTALL_MODE="${1#*=}"; shift ;;
            --with-devcontainer) WITH_DEVCONTAINER=true; shift ;;
            -h|--help) grep '^#' "$0" | sed 's/^#//' | head -n 40; exit 0 ;;
            *) print_error "Unknown argument: $1"; exit 1 ;;
        esac
    done
    if [[ -n "$INSTALL_MODE" && "$INSTALL_MODE" != "baremetal" && "$INSTALL_MODE" != "devcontainer" ]]; then
        print_error "Invalid --mode '$INSTALL_MODE' (expected 'baremetal' or 'devcontainer')"
        exit 1
    fi
}

select_mode() {
    if [[ -z "$INSTALL_MODE" ]]; then
        print_section "SELECT INSTALL MODE"
        echo "  1) Devcontainer- Only base system + Docker + dev container tooling."
        echo "                   No native dev tools on the host; you develop"
        echo "                   entirely inside containers. (Recommended)"
        echo ""
        echo "  2) Baremetal   - Full dev toolchain installed on this machine"
        echo "                   (languages, runtimes, databases, Docker, etc.)"
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
#              SECTION 2: ESSENTIAL SOFTWARE
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

section_build_tools() {
    print_section "ESSENTIAL SOFTWARE"

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
    # On Debian, eza / lazygit / starship are frequently missing from stable.
    # Pull them from their vendor installers as a fallback (best-effort).
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        if ! run_user bash -c 'command -v starship >/dev/null 2>&1'; then
            soft "starship (vendor installer)" \
                run_user bash -c 'curl -fsSL https://starship.rs/install.sh | sh -s -- --yes'
        fi
    fi

    # ── Desktop / gaming apps (best-effort) ───────────────────────────────────
    # Steam pulls i386 (Debian) / multilib (Arch) deps enabled in section 1.
    print_info "Installing desktop/gaming apps (best-effort)..."
    local dapp
    for dapp in "${PKG_DESKTOP[@]}"; do
        print_info "  → $dapp"
        soft "desktop app: $dapp" pkg_install "$dapp"
    done

    # Shell integration for the tools just installed (guarded, so a missing
    # binary is a harmless no-op in future shells).
    print_info "Wiring zoxide, fzf and starship into ~/.bashrc..."
    append_bashrc 'command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"' '# zoxide (smarter cd)'
    # Debian ships fzf's key bindings as a file; fall back to `fzf --bash`.
    append_bashrc '[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash; command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash 2>/dev/null)" 2>/dev/null' '# fzf (fuzzy finder)'
    append_bashrc 'command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"' '# starship (prompt)'
    # Debian names the binaries batcat / fdfind — add friendly aliases.
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
        append_bashrc 'command -v batcat >/dev/null 2>&1 && alias bat=batcat' '# bat alias (Debian names it batcat)'
        append_bashrc 'command -v fdfind >/dev/null 2>&1 && alias fd=fdfind' '# fd alias (Debian names it fdfind)'
    fi

    print_success "Essential software processed"
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
#              SECTION 4: MULLVAD VPN
#
#   Debian/Ubuntu: official Mullvad apt repository.
#   Arch:          'mullvad-vpn-bin' from the AUR.
################################################################################

section_mullvad_vpn() {
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
#              SECTION 5: ZED EDITOR & ATUIN
#
#   Both use official, distro-agnostic curl installers (same as Fedora).
################################################################################

section_zed_atuin() {
    print_section "ZED EDITOR"

    if run_user bash -c 'command -v zed >/dev/null 2>&1 || [ -x "$HOME/.local/bin/zed" ]'; then
        print_info "Zed already installed — skipping"
    else
        print_info "Installing Zed editor..."
        soft "Zed editor" run_user bash -c 'curl -fsSL https://zed.dev/install.sh | bash'
    fi

    print_section "ATUIN SHELL HISTORY MANAGER"

    if run_user bash -c 'command -v atuin >/dev/null 2>&1 || [ -x "$HOME/.local/bin/atuin" ] || [ -x "$HOME/.atuin/bin/atuin" ]'; then
        print_info "Atuin already installed — skipping"
    else
        print_info "Installing Atuin shell history manager (non-interactive)..."
        soft "Atuin" run_user bash -c 'curl --proto '"'"'=https'"'"' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive'
    fi
}

################################################################################
#              SECTION 6: GIT CONFIGURATION
################################################################################

section_git_config() {
    print_section "GIT CONFIGURATION"

    print_info "Configuring Git..."
    run_user git config --global user.name "$GIT_USERNAME"
    run_user git config --global user.email "$GIT_EMAIL"
    run_user git config --global pull.rebase false
    run_user git config --global init.defaultBranch main
    print_success "Git configured"

    run_user git config --global --list | grep -E "user\.|pull\.|init\." || true
}

################################################################################
#              SECTION 7: DEV TOOLS  (baremetal only)
#
#   Native runtimes, languages, and local database services. Mirrors the
#   Fedora script; language installers (NVM, Rustup, SDKMAN, Flutter) are
#   distro-agnostic, package/DB bits are family-specific.
#
#   SECURITY NOTE: Database services are configured for LOCAL development only.
################################################################################

section_dev_tools() {
    print_section "DEV TOOLS"

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
    print_info "Installing Node LTS via NVM..."
    soft "Node LTS" run_user bash -c \
        'export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" &&
         nvm install --lts && nvm use --lts && nvm alias default node'
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
    append_bashrc 'export PATH="$PATH:$HOME/.flutter/bin"' '# Flutter SDK'
    soft "Flutter precache" run_user bash -c "export PATH=\"\$PATH:$FLUTTER_DIR/bin\" && flutter precache"
    append_bashrc 'export CHROME_EXECUTABLE=/var/lib/flatpak/exports/bin/com.brave.Browser' '# Flutter: use Brave for web'

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
#              SECTION 8: DOCKER & DOCKER COMPOSE
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
#              SECTION 9: SYSTEM CUSTOMIZATION
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
#              SECTION 10: DEV CONTAINERS
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
    append_bashrc 'export PATH="$HOME/.local/bin:$PATH"' '# ~/.local/bin on PATH'

    print_info "Scaffold a project: cd into it and run 'devinit'"
    print_info "Then reopen the project in a container from your editor (Zed or VS Code)"
}

################################################################################
#              SECTION 11: INSTALLATION COMPLETE - SUMMARY
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

    print_success "Setup complete. Happy coding!"
}

################################################################################
#                         MAIN EXECUTION FLOW
################################################################################

main() {
    print_info "Starting Debian/Arch Developer Setup..."
    check_root
    detect_distro
    map_packages
    parse_args "$@"
    select_mode

    # ── Common base (sections 1-6) ────────────────────────────────────────────
    section_system_updates   # Section 1
    section_build_tools      # Section 2
    section_flatpak          # Section 3
    section_mullvad_vpn      # Section 4
    section_zed_atuin        # Section 5
    section_git_config       # Section 6

    # ── Native dev tools (section 7) — baremetal only ─────────────────────────
    if [[ "$INSTALL_MODE" == "baremetal" ]]; then
        section_dev_tools    # Section 7
    else
        print_info "Skipping native dev tools (section 7) — devcontainer mode."
    fi

    # ── Docker + customization (sections 8-9) — both modes ─────────────────────
    section_docker           # Section 8
    section_customization    # Section 9

    # ── Dev containers (section 10) ───────────────────────────────────────────
    if [[ "$INSTALL_MODE" == "devcontainer" || "$WITH_DEVCONTAINER" == "true" ]]; then
        section_devcontainers   # Section 10
    else
        print_info "Skipping dev containers (section 10)."
    fi

    section_summary
}

main "$@"
