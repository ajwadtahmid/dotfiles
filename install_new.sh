#!/bin/bash

################################################################################
#                   FEDORA DEVELOPER SETUP SCRIPT
#
#   A comprehensive installation script for Fedora Linux developers
#   Includes: Node.js (NVM), Python, Docker, VS Code,
#   and essential development tools
#
#   Usage: chmod +x install.sh && bash install.sh
#   Tested on: Fedora 39+
#
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
#                         CONFIGURATION SECTION
#                    (Customize before running the script)
################################################################################

# Git Configuration (set your details here)
GIT_USERNAME="Ajwad Tahmid"           # Change to your name
GIT_EMAIL="dev@ajwadtahmid.com" # Change to your email

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run with sudo"
        exit 1
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

    print_info "Installing RPM Fusion repositories..."
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                      https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    print_success "RPM Fusion installed"
}

################################################################################
#               SECTION 2: ESSENTIAL SOFTWARES
################################################################################

section_build_tools() {
    print_section "ESSENTIAL SOFTWARES"

    print_info "Installing essential softwares..."
    dnf install -y \
        gcc \
        g++ \
        make \
        cmake \
        git \
        git-lfs \
        htop \
        fastfetch \
        zsh \
        curl \
        wget

    print_info "Initializing Git LFS..."
    sudo -u "$SUDO_USER" git lfs install
    print_success "Git LFS initialized"
}

################################################################################
#              SECTION 3: FLATPAK & FLATHUB SETUP
################################################################################

section_flatpak() {
    print_section "FLATPAK & FLATHUB SETUP"

    print_info "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    print_success "Flathub added"

    print_info "Installing Flatpak applications..."
    flatpak install -y flathub \
        io.github.kolunmi.Bazaar \
        com.discordapp.Discord \
        com.brave.Browser \
        app.zen_browser.zen \
        org.videolan.VLC \
        io.ente.photos \
        com.github.tchx84.Flatseal \
        org.onlyoffice.desktopeditors \
        com.vysp3r.ProtonPlus \
        org.flameshot.Flameshot \
        org.qbittorrent.qBittorrent \
        im.riot.Riot \
        com.obsproject.Studio \
        io.github.peazip.PeaZip \
        org.mozilla.Thunderbird \
        org.kde.kdenlive \
        io.freetubeapp.FreeTube \
        com.github.Matoking.protontricks \
        dev.zed.Zed \
        com.usebruno.Bruno \
        org.godotengine.Godot \
        fr.handbrake.ghb \
        net.cozic.joplin_desktop
    print_success "Core Flatpak applications installed"
}

#   Uncomment the apps you need, otherwise keep commented.
#
#     flatpak install flathub org.fedoraproject.MediaWriter
#
#     flatpak install flathub fr.handbrake.ghb
#
#     flatpak install flathub chat.schildi.desktop
#
#     flatpak install flathub org.gimp.GIMP
#
#     flatpak install flathub org.gnome.Boxes
#
#     flatpak install flathub com.mojang.Minecraft
#
#     flatpak install flathub dev.vencord.Vesktop
#
#     flatpak install flathub com.heroicgameslauncher.hgl
#
#     flatpak install flathub org.kde.okular
#
#     flatpak install flathub com.protonvpn.www
#
#     flatpak install flathub com.visualstudio.code

################################################################################
#              SECTION 5: MULLVAD VPN
#
#   Mullvad is an open-source, privacy-focused VPN provider.
#   Install from official Mullvad repository for security and automatic updates.
################################################################################

section_mullvad_vpn() {
    print_section "MULLVAD VPN"

    print_info "Adding Mullvad repository..."
    dnf config-manager addrepo --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo --overwrite
    print_success "Mullvad repository added"

    print_info "Installing Mullvad VPN..."
    dnf install -y mullvad-vpn
    print_success "Mullvad VPN installed"

    print_info "Official site: https://mullvad.net"
}

################################################################################
#              SECTION 7: PYTHON 3 WITH PIP & VENV
#
#   Python 3 with virtual environment support for isolated project dependencies.
#   Essential for scripting, data science, and automation tasks.
################################################################################

section_python() {
    print_section "PYTHON 3 WITH PIP & VENV"

    print_info "Installing Python 3 with development tools..."
    dnf install -y python3 python3-pip python3-devel
    print_success "Python 3 installed"

    print_info "Upgrading pip for user..."
    sudo -u "$SUDO_USER" python3 -m pip install --upgrade pip --user
    print_success "pip upgraded"

    print_info "Verifying Python installation..."
    python3 --version
    pip3 --version
    print_success "Python verified"
}

################################################################################
#              SECTION 8: DOCKER & DOCKER COMPOSE
#
#   Docker enables containerized development and testing.
#   Auto-start daemon is configured to run on boot.
#   Dev Containers extension for VS Code allows container-based development.
#
#   SECURITY NOTE: Adding user to the docker group grants privileges equivalent
#   to root access. Only add trusted users to the docker group. Users in the
#   docker group can mount volumes and access host files with full permissions.
#   For production systems, consider using rootless Docker.
#   See: https://docs.docker.com/engine/security/rootless/
################################################################################

section_docker() {
    print_section "DOCKER & DOCKER COMPOSE"

    print_info "Installing Docker..."
    dnf install -y docker docker-compose
    print_success "Docker installed"

    print_warning "SECURITY: Adding user to docker group grants root-level privileges."
    print_warning "Only add trusted users. For more info: https://docs.docker.com/engine/install/linux-postinstall/"

    print_info "Adding current user to docker group..."
    usermod -aG docker "$SUDO_USER"
    print_success "User added to docker group (restart shell to take effect)"

    print_info "Enabling and starting Docker daemon..."
    systemctl enable docker
    systemctl start docker
    print_success "Docker daemon enabled and started"

    print_info "Verifying Docker installation..."
    docker --version
    docker-compose --version
    print_success "Docker verified"

    print_warning "You may need to restart your shell for group changes to take effect"
    print_warning "Or run: newgrp docker"
}

################################################################################
#              SECTION 9: GIT CONFIGURATION
#
#   Git is configured with the username and email set at the top of the script.
################################################################################

section_git_config() {
    print_section "GIT CONFIGURATION"

    # Validate that user changed the default values
    if [[ "$GIT_USERNAME" == "Your Name" ]] || [[ "$GIT_EMAIL" == "your.email@example.com" ]]; then
        print_warning "Git configuration variables have default values!"
        print_warning "Please edit this script and set GIT_USERNAME and GIT_EMAIL before running."
        print_info "Continuing with default values (you can change them later with git config)"
    fi

    print_info "Configuring Git..."
    sudo -u "$SUDO_USER" git config --global user.name "$GIT_USERNAME"
    sudo -u "$SUDO_USER" git config --global user.email "$GIT_EMAIL"
    sudo -u "$SUDO_USER" git config --global pull.rebase false
    sudo -u "$SUDO_USER" git config --global init.defaultBranch main
    print_success "Git configured"

    print_info "Git configuration:"
    sudo -u "$SUDO_USER" git config --global --list | grep -E "user\.|pull\.|init\."

    print_info "To update Git config later, run:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
}

################################################################################
#              SECTION 10: SYSTEM CUSTOMIZATION
#
#   Sets hostname and performs final updates.
################################################################################

section_customization() {
    print_section "SYSTEM CUSTOMIZATION"

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

    print_info "Running final system updates..."
    dnf upgrade -y
    flatpak update -y
    print_success "System updated"
}

################################################################################
#              SECTION 11: INSTALLATION COMPLETE - SUMMARY
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

    print_success "Setup complete. Happy coding!"
}

################################################################################
#                         MAIN EXECUTION FLOW
################################################################################

main() {
    print_info "Starting Fedora Developer Setup..."
    check_root

    section_system_updates
    section_build_tools
    section_flatpak
    section_mullvad_vpn
    section_python
    section_docker
    section_git_config
    section_customization
    section_summary
}

# Run main function
main
