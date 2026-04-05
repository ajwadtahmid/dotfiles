#!/bin/bash

################################################################################
#                   FEDORA DEVELOPER SETUP SCRIPT
#                   
#   A comprehensive installation script for Fedora Linux developers
#   Includes: Node.js (NVM), Java, Maven, Rust, Docker, databases, 
#   VS Code, and essential development tools
#
#   Usage: bash install.sh
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
GIT_USERNAME="Your Name"           # Change to your name
GIT_EMAIL="your.email@example.com" # Change to your email

# Hostname will be selected interactively during installation
# Options: fedora-desktop or fedora-laptop

# Optional components - set to 'true' or 'false'
INSTALL_GIMP=false                  # GIMP image editor
INSTALL_MEDIAWRITER=false           # Fedora Media Writer (USB bootable)
INSTALL_SCHILDI=false               # Schildi Chat (chat client)
INSTALL_MINECRAFT=false             # Minecraft launcher
INSTALL_HEROIC_GAMES=false          # Heroic Games Launcher
INSTALL_PROTONVPN=false             # ProtonVPN
INSTALL_OKULAR=false                # Okular PDF reader
INSTALL_VESKTOP=false               # Vesktop (Discord alternative)
INSTALL_LIMO=false                  # Limo (mod manager)

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

check_internet() {
    print_info "Checking internet connectivity..."
    if ! ping -c 1 8.8.8.8 &> /dev/null && ! ping -c 1 1.1.1.1 &> /dev/null; then
        print_error "No internet connection detected. This script requires internet access."
        exit 1
    fi
    print_success "Internet connection verified"
}

################################################################################
#                    SECTION 1: SYSTEM UPDATES & RPM FUSION
################################################################################

section_system_updates() {
    print_section "SYSTEM UPDATES & RPM FUSION SETUP"
    
    print_info "Updating system packages..."
    dnf upgrade -y
    print_success "System updated"
    
    print_info "Installing RPM Fusion repositories..."
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                      https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    print_success "RPM Fusion installed"
}

################################################################################
#               SECTION 2: ESSENTIAL BUILD TOOLS & DEVELOPMENT
################################################################################

section_build_tools() {
    print_section "ESSENTIAL BUILD TOOLS & DEVELOPMENT PACKAGES"
    
    print_info "Installing essential development tools..."
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
    print_success "Build tools installed"
    
    print_info "Initializing Git LFS..."
    sudo -u "$SUDO_USER" git lfs install
    print_success "Git LFS initialized"
}

################################################################################
#              SECTION 3: FLATPAK & FLATHUB SETUP
################################################################################

section_flatpak() {
    print_section "FLATPAK & FLATHUB CONFIGURATION"
    
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

################################################################################
#           SECTION 4: MANDATORY & OPTIONAL FLATPAK APPLICATIONS
################################################################################

section_flatpak_applications() {
    print_section "OPTIONAL FLATPAK APPLICATIONS"
    
    optional_apps=""
    
    [[ $INSTALL_GIMP == true ]] && optional_apps="$optional_apps org.gimp.GIMP"
    [[ $INSTALL_MEDIAWRITER == true ]] && optional_apps="$optional_apps org.fedoraproject.MediaWriter"
    [[ $INSTALL_SCHILDI == true ]] && optional_apps="$optional_apps chat.schildi.desktop"
    [[ $INSTALL_MINECRAFT == true ]] && optional_apps="$optional_apps com.mojang.Minecraft"
    [[ $INSTALL_HEROIC_GAMES == true ]] && optional_apps="$optional_apps com.heroicgameslauncher.hgl"
    [[ $INSTALL_PROTONVPN == true ]] && optional_apps="$optional_apps com.protonvpn.www"
    [[ $INSTALL_OKULAR == true ]] && optional_apps="$optional_apps org.kde.okular"
    [[ $INSTALL_VESKTOP == true ]] && optional_apps="$optional_apps dev.vencord.Vesktop"
    [[ $INSTALL_LIMO == true ]] && optional_apps="$optional_apps io.github.limo_app.limo"
    
    if [[ -n "$optional_apps" ]]; then
        print_info "Installing optional applications..."
        flatpak install -y flathub $optional_apps
        print_success "Optional applications installed"
    else
        print_info "No optional applications selected"
    fi
}

################################################################################
#          SECTION 5: JAVA 21 LTS & JAVA 17 + 11 WITH MAVEN
#
#   JAVA_HOME:  Points to the Java installation (/usr/lib/jvm/java-XX-openjdk)
#               Used by: Maven, IDEs, build tools, Docker, applications
#               Purpose: Find Java compiler (javac) and runtime (java)
#
#   M2_HOME:    Points to Maven installation (/usr/share/maven)
#               Used by: Maven for config files and plugins
#               Purpose: Locate Maven binaries, settings, and plugin cache
#
#   These variables allow tools to automatically find and use Java/Maven
#   without hardcoding paths. Essential for reproducible builds.
################################################################################

section_java_maven() {
    print_section "JAVA 21 LTS, 17 & 11 WITH MAVEN"
    
    print_info "Installing Java 21 LTS (default)..."
    dnf install -y java-21-openjdk java-21-openjdk-devel
    print_success "Java 21 LTS installed"
    
    print_info "Installing Java 17..."
    dnf install -y java-17-openjdk java-17-openjdk-devel
    print_success "Java 17 installed"
    
    print_info "Installing Java 11 (legacy compatibility)..."
    dnf install -y java-11-openjdk java-11-openjdk-devel
    print_success "Java 11 installed"
    
    print_info "Setting Java 21 as default..."
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-21-openjdk/bin/java 1
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-21-openjdk/bin/javac 1
    update-alternatives --set java /usr/lib/jvm/java-21-openjdk/bin/java
    update-alternatives --set javac /usr/lib/jvm/java-21-openjdk/bin/javac
    print_success "Java 21 set as default"
    
    print_warning "To switch to Java 17 or 11, run: sudo update-alternatives --config java"
    
    print_info "Installing Maven (latest)..."
    dnf install -y maven
    print_success "Maven installed"
    
    # Set JAVA_HOME and M2_HOME in ~/.bashrc
    print_info "Configuring JAVA_HOME and M2_HOME environment variables..."
    
    BASHRC="$HOME/.bashrc"
    
    # Check if already set
    if ! grep -q "export JAVA_HOME" "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'EOF'

# ============= JAVA & MAVEN CONFIGURATION =============
# JAVA_HOME: Points to Java installation directory
#   - Used by Maven, IDEs, and build tools to find the Java compiler
#   - Change to /usr/lib/jvm/java-17-openjdk or /usr/lib/jvm/java-11-openjdk to use other versions
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk

# M2_HOME: Points to Maven installation directory
#   - Used by Maven to locate configuration files and plugins
#   - Default local repository: ~/.m2/repository
export M2_HOME=/usr/share/maven

# Add Maven to PATH for easy command-line access
export PATH="$M2_HOME/bin:$JAVA_HOME/bin:$PATH"
EOF
        print_success "Environment variables added to ~/.bashrc"
    else
        print_warning "Environment variables already exist in ~/.bashrc, skipping"
    fi
    
    print_info "Verifying Java installation..."
    java -version
    print_success "Java verified"
    
    print_info "Verifying Maven installation..."
    mvn --version
    print_success "Maven verified"
}

################################################################################
#              SECTION 6: SPRING BOOT CLI
#
#   Spring Boot CLI is a command-line tool for quickly scaffolding
#   new Spring Boot projects. Essential for rapid prototyping and
#   project generation.
#
#   Quick start:
#   spring boot new --name my-app
################################################################################

section_spring_boot_cli() {
    print_section "SPRING BOOT CLI"
    
    print_info "Installing Spring Boot CLI..."
    dnf install -y spring-boot-cli
    print_success "Spring Boot CLI installed"
    
    print_info "Verifying Spring Boot CLI..."
    spring --version
    print_success "Spring Boot CLI verified"
}

################################################################################
#              SECTION 6B: MULLVAD VPN
#
#   Mullvad is an open-source, privacy-focused VPN provider.
#   Install from official Mullvad repository for security and automatic updates.
################################################################################

section_mullvad_vpn() {
    print_section "MULLVAD VPN"
    
    print_info "Adding Mullvad repository..."
    dnf install -y https://repository.mullvad.net/fedora/mullvad-latest.fc$(rpm -E %fedora).noarch.rpm
    print_success "Mullvad repository added"
    
    print_info "Installing Mullvad VPN..."
    dnf install -y mullvad
    print_success "Mullvad VPN installed"
    
    print_info "Starting Mullvad service..."
    systemctl enable mullvad-daemon
    systemctl start mullvad-daemon
    print_success "Mullvad VPN service enabled and started"
    
    print_info "Mullvad VPN is installed. Launch with: mullvad"
    print_info "Official site: https://mullvad.net"
}

################################################################################
#              SECTION 7: NODE.JS (NVM - NODE VERSION MANAGER)
#
#   NVM allows you to manage multiple Node.js versions simultaneously.
#   Essential for working on projects with different Node requirements.
#   
#   Why NVM over direct installation:
#   - Switch versions instantly: nvm use 20 vs nvm use 18
#   - Per-project version control (.nvmrc files)
#   - Easier to test across versions
#   - Isolated from system Node (if any)
#   - Industry standard for JavaScript developers
#
#   This installation includes Node.js, npm, and npx automatically.
#   Next.js will be installed as a project dependency, not system-wide.
################################################################################

section_node_nvm() {
    print_section "NODE.JS VIA NVM (NODE VERSION MANAGER)"
    
    print_info "Installing NVM (Node Version Manager)..."
    sudo -u "$SUDO_USER" bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'
    
    # Source NVM in current shell for use in this script
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    print_success "NVM installed"
    
    print_info "Installing Node.js LTS via NVM..."
    sudo -u "$SUDO_USER" bash -c 'source $HOME/.nvm/nvm.sh && nvm install --lts && nvm use --lts && nvm alias default node'
    print_success "Node.js LTS installed"
    
    print_info "Verifying Node.js installation..."
    sudo -u "$SUDO_USER" bash -c 'source $HOME/.nvm/nvm.sh && node --version && npm --version && npx --version'
    print_success "Node.js verified"
    
    print_info "NVM is now available. Next.js can be installed with: npx create-next-app@latest"
}

################################################################################
#              SECTION 8: RUST & CARGO
#
#   Rust is installed via rustup, the official Rust toolchain manager.
#   This gives you Rust, Cargo (package manager), and rustup for updates.
#
#   Why Rust:
#   - Systems programming, performance-critical code
#   - WebAssembly (WASM) compilation
#   - Growing ecosystem for full-stack development
################################################################################

section_rust() {
    print_section "RUST & CARGO"
    
    print_info "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    
    # Source Rust in current shell
    source "$HOME/.cargo/env"
    
    print_success "Rust installed"
    
    print_info "Verifying Rust installation..."
    rustc --version
    cargo --version
    print_success "Rust verified"
}

################################################################################
#              SECTION 9: PYTHON 3 WITH PIP & VENV
#
#   Python 3 with virtual environment support for isolated project dependencies.
#   Essential for scripting, data science, and automation tasks.
################################################################################

section_python() {
    print_section "PYTHON 3 WITH PIP & VENV"
    
    print_info "Installing Python 3 with development tools..."
    dnf install -y python3 python3-pip python3-devel python3-venv
    print_success "Python 3 installed"
    
    print_info "Upgrading pip..."
    python3 -m pip install --upgrade pip
    print_success "pip upgraded"
    
    print_info "Verifying Python installation..."
    python3 --version
    pip3 --version
    print_success "Python verified"
}

################################################################################
#              SECTION 10: DOCKER & DOCKER COMPOSE
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
#              SECTION 11: DATABASES
#
#   PostgreSQL, MongoDB, and MariaDB are essential for full-stack development.
#   All configured to auto-start on boot.
################################################################################

section_databases() {
    print_section "DATABASE SERVERS (POSTGRESQL, MONGODB, MARIADB)"
    
    print_info "Installing PostgreSQL server and client..."
    dnf install -y postgresql postgresql-server postgresql-contrib
    
    # Check if PostgreSQL database is already initialized
    if [[ ! -d /var/lib/pgsql/data ]]; then
        print_info "Initializing PostgreSQL database..."
        postgresql-setup initdb
    else
        print_info "PostgreSQL database already initialized, skipping initdb"
    fi
    
    systemctl enable postgresql
    systemctl start postgresql
    print_success "PostgreSQL installed and configured"
    
    print_info "Installing MongoDB server..."
    dnf install -y mongodb-server mongodb-mongosh
    systemctl enable mongod
    systemctl start mongod
    print_success "MongoDB installed and configured"
    
    print_warning "SECURITY: MongoDB is installed without authentication enabled by default."
    print_warning "For production use, enable authentication: https://docs.mongodb.com/manual/tutorial/enable-authentication/"
    
    print_info "Installing MariaDB server..."
    dnf install -y mariadb-server
    
    # MariaDB auto-setup (non-interactive)
    systemctl enable mariadb
    systemctl start mariadb
    print_success "MariaDB installed and configured"
    
    print_warning "SECURITY: MariaDB root password is not set. For security, run: sudo mysql_secure_installation"
    
    print_info "Quick start commands:"
    echo "  PostgreSQL:"
    echo "    psql -U postgres                    # Connect to PostgreSQL"
    echo "    sudo systemctl status postgresql    # Check status"
    echo ""
    echo "  MongoDB:"
    echo "    mongosh                             # Connect to MongoDB"
    echo "    sudo systemctl status mongod        # Check status"
    echo ""
    echo "  MariaDB:"
    echo "    sudo mysql -u root                  # Connect to MariaDB"
    echo "    sudo systemctl status mariadb       # Check status"
}

################################################################################
#              SECTION 12: VS CODE WITH MICROSOFT REPOSITORY
#
#   VS Code is installed directly from Microsoft's official RPM repository
#   for automatic updates. Telemetry is disabled by default.
#   Dev Containers extension is installed for container-based development.
################################################################################

section_vscode() {
    print_section "VS CODE WITH MICROSOFT REPOSITORY"
    
    print_info "Adding Microsoft's VS Code repository..."
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    
    cat > /etc/yum.repos.d/vscode.repo << EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    print_success "Microsoft repository added"
    
    print_info "Installing VS Code..."
    dnf install -y code
    print_success "VS Code installed"
    
    # Wait for code binary to be available
    print_info "Waiting for VS Code binary to be available..."
    for i in {1..30}; do
        if command -v code &> /dev/null; then
            print_success "VS Code binary found"
            break
        fi
        if [[ $i -eq 30 ]]; then
            print_warning "VS Code binary not found in PATH. Extension installation skipped. Run manually: code --install-extension ms-vscode-remote.remote-containers"
            return
        fi
        sleep 1
    done
    
    print_info "Installing Dev Containers extension..."
    sudo -u "$SUDO_USER" code --install-extension ms-vscode-remote.remote-containers || print_warning "Dev Containers extension installation may require VS Code to be run manually"
    print_success "Dev Containers extension installation attempted"
    
    print_info "Disabling telemetry..."
    sudo -u "$SUDO_USER" mkdir -p "$HOME/.config/Code/User"
    cat >> "$HOME/.config/Code/User/settings.json" << 'EOF'
{
  "telemetry.telemetryLevel": "off"
}
EOF
    print_success "Telemetry disabled (telemetry.telemetryLevel: off)"
}

################################################################################
#              SECTION 13: GIT CONFIGURATION
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
    git config --global user.name "$GIT_USERNAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global pull.rebase false
    git config --global init.defaultBranch main
    print_success "Git configured"
    
    print_info "Git configuration:"
    git config --global --list | grep -E "user\.|pull\.|init\."
    
    print_info "To update Git config later, run:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
}

################################################################################
#              SECTION 14: SYSTEM CUSTOMIZATION
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
    hostnamectl set-hostname "$FINAL_HOSTNAME"
    
    if [[ $? -eq 0 ]]; then
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
#              SECTION 15: INSTALLATION COMPLETE - SUMMARY
################################################################################

section_summary() {
    print_section "INSTALLATION COMPLETE!"
    
    cat << EOF
${GREEN}════════════════════════════════════════════════════════${NC}
${GREEN}                   SETUP COMPLETE! 🎉${NC}
${GREEN}════════════════════════════════════════════════════════${NC}

${BLUE}✓ Installed Components:${NC}
  Build Tools: gcc, make, cmake, git, git-lfs
  Java: Java 21 LTS (default) + Java 17 + Java 11
  Build Tools: Maven, Spring Boot CLI
  VPN: Mullvad VPN (privacy-focused)
  Node.js: NVM (Node Version Manager) with npm, npx
  Languages: Rust (rustup), Python 3 (pip, venv)
  Containerization: Docker, Docker Compose
  Databases: PostgreSQL, MongoDB, MariaDB (auto-start)
  Development: VS Code (Microsoft repo) with Dev Containers
  Applications: 20+ Flatpak apps including Godot, HandBrake, FreeTube

${YELLOW}⚠ CRITICAL: Restart Your Shell${NC}
  Your shell must be restarted for the following to work:
  ${BLUE}source ~/.bashrc${NC} or ${BLUE}exec bash${NC} or open a new terminal window
  
  This is needed for:
    • NVM (Node Version Manager)
    • Docker group membership
    • Updated PATH variables

${YELLOW}⚠ Security Notices:${NC}
  1. Docker: User added to docker group (= root access)
     Only trust this account with sensitive data
     https://docs.docker.com/engine/security/rootless/
  
  2. MongoDB: Installed WITHOUT authentication by default
     For production: https://docs.mongodb.com/manual/tutorial/enable-authentication/
  
  3. MariaDB: No root password set
     Run: ${BLUE}sudo mysql_secure_installation${NC}

${BLUE}🔄 Switch Between Java Versions:${NC}
  ${BLUE}sudo update-alternatives --config java${NC}
  ${BLUE}sudo update-alternatives --config javac${NC}
  Default: Java 21 | Available: Java 17, 11

${BLUE}📝 Git Configuration:${NC}
  Username: ${GREEN}${GIT_USERNAME}${NC}
  Email:    ${GREEN}${GIT_EMAIL}${NC}
  Config:   ~/.gitconfig
  Update:   ${BLUE}git config --global user.name "Name"${NC}

${BLUE}🏠 System Hostname:${NC}
  ${GREEN}${FINAL_HOSTNAME}${NC}

${BLUE}🔐 VPN:${NC}
  Mullvad VPN installed and running
  Launch: ${BLUE}mullvad${NC}

${BLUE}🗄️ Database Access:${NC}
  PostgreSQL: ${BLUE}psql -U postgres${NC}
  MongoDB:    ${BLUE}mongosh${NC}
  MariaDB:    ${BLUE}sudo mysql -u root${NC}

${BLUE}📁 Environment Variables:${NC}
  JAVA_HOME=/usr/lib/jvm/java-21-openjdk
  M2_HOME=/usr/share/maven
  Added to: ~/.bashrc

${BLUE}🚀 Next Steps:${NC}
  1. ${YELLOW}Close and reopen your terminal${NC} to activate NVM, Docker, and PATH changes
  2. Install JetBrains Toolbox (manual)
      https://www.jetbrains.com/toolbox/
  3. Install Android Studio (manual, for Flutter/React Native)
      https://developer.android.com/studio
  4. Generate SSH key for GitHub/GitLab (optional):
      ${BLUE}ssh-keygen -t ed25519${NC}
  5. Verify installations after restarting shell:
      ${BLUE}node --version${NC}
      ${BLUE}docker ps${NC}

${GREEN}════════════════════════════════════════════════════════${NC}
${GREEN}       Happy coding! Environment ready. 🚀${NC}
${GREEN}════════════════════════════════════════════════════════${NC}

EOF
}

################################################################################
#                         MAIN EXECUTION FLOW
################################################################################

main() {
    print_info "Starting Fedora Developer Setup..."
    check_root
    check_internet
    
    section_system_updates
    section_build_tools
    section_flatpak
    section_flatpak_applications
    section_java_maven
    section_spring_boot_cli
    section_mullvad_vpn
    section_node_nvm
    section_rust
    section_python
    section_docker
    section_databases
    section_vscode
    section_git_config
    section_customization
    section_summary
}

# Run main function
main
