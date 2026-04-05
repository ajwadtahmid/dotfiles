#!/bin/bash

################################################################################
#                   FEDORA DEVELOPER SETUP SCRIPT
#                   
#   A comprehensive installation script for Fedora Linux developers
#   Includes: Node.js (NVM), Java, Maven, Rust, Docker, databases, 
#   VS Code, and essential development tools
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
#          SECTION 5: JAVA 21 LTS & JAVA 25 WITH MAVEN
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
    print_section "JAVA 21 LTS & 25 WITH MAVEN"

    print_info "Installing Java 21 LTS (default)..."
    dnf install -y java-21-openjdk java-21-openjdk-devel
    print_success "Java 21 LTS installed"

    print_info "Installing Java 25 (latest)..."
    dnf install -y java-25-openjdk java-25-openjdk-devel
    print_success "Java 25 installed"

    print_info "Setting Java 21 LTS as default..."
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-21-openjdk/bin/java 1
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-21-openjdk/bin/javac 1
    update-alternatives --set java /usr/lib/jvm/java-21-openjdk/bin/java
    update-alternatives --set javac /usr/lib/jvm/java-21-openjdk/bin/javac
    print_success "Java 21 LTS set as default"

    print_warning "To switch between Java versions, run: sudo update-alternatives --config java"

    print_info "Installing Maven (latest)..."
    dnf install -y maven
    print_success "Maven installed"

    # Set JAVA_HOME and M2_HOME in ~/.bashrc
    print_info "Configuring JAVA_HOME and M2_HOME environment variables..."

    # Use actual user home, not root's home
    REAL_HOME=$(eval echo ~$SUDO_USER)
    BASHRC="$REAL_HOME/.bashrc"

    # Check if already set
    if ! grep -q "export JAVA_HOME" "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'EOF'

# ============= JAVA & MAVEN CONFIGURATION =============
# JAVA_HOME: Points to Java installation directory
#   - Used by Maven, IDEs, and build tools to find the Java compiler
#   - Default: Java 21 LTS
#   - Alternatives: /usr/lib/jvm/java-25-openjdk (Java 25)
#   - Switch versions: sudo update-alternatives --config java
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

    # Get actual user home
    REAL_HOME=$(eval echo ~$SUDO_USER)
    SDKMAN_DIR="$REAL_HOME/.sdkman"

    # Check if SDKMAN already installed
    if [[ ! -d "$SDKMAN_DIR" ]]; then
        print_info "Installing SDKMAN (Software Development Kit Manager)..."
        sudo -u "$SUDO_USER" bash -c 'curl -s "https://get.sdkman.io" | bash'
        print_success "SDKMAN installed"
    else
        print_info "SDKMAN already installed"
    fi

    print_info "Installing Spring Boot CLI via SDKMAN..."
    # Source SDKMAN and install Spring Boot
    sudo -u "$SUDO_USER" bash -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && sdk install springboot'
    print_success "Spring Boot CLI installed"

    print_info "Verifying Spring Boot CLI..."
    set +e
    version_output=$(sudo -u "$SUDO_USER" bash -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && spring --version' 2>&1)
    version_result=$?
    set -e

    if [[ $version_result -eq 0 ]]; then
        echo "$version_output"
        print_success "Spring Boot CLI verified"
    else
        print_warning "Spring Boot CLI verification may need shell restart"
        echo "Output: $version_output"
    fi

    print_info "SDKMAN also manages other tools: Java, Gradle, Maven, etc."
    echo "  View available tools: sdk list"
    echo "  Install a tool: sdk install <tool-name>"
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
    dnf config-manager addrepo --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo --overwrite
    print_success "Mullvad repository added"

    print_info "Installing Mullvad VPN..."
    dnf install -y mullvad-vpn
    print_success "Mullvad VPN installed"

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

    # Get the actual user's home directory
    USER_HOME=$(eval echo "~$SUDO_USER")

    # Install Rust as the actual user, not root
    sudo -u "$SUDO_USER" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'

    print_success "Rust installed"

    print_info "Verifying Rust installation..."

    # Verify using the user's Rust installation
    sudo -u "$SUDO_USER" bash -c 'source $HOME/.cargo/env && rustc --version'
    sudo -u "$SUDO_USER" bash -c 'source $HOME/.cargo/env && cargo --version'

    print_success "Rust verified"

    print_info "Rust installation location: $USER_HOME/.cargo"
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
    dnf install -y python3 python3-pip python3-devel
    print_success "Python 3 installed"

    # Check if venv is available, install if needed
    if ! python3 -m venv --help &>/dev/null; then
        print_info "Installing python3-venv..."
        dnf install -y python3-venv || print_warning "python3-venv not available in repos"
    fi

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
#   PostgreSQL and MariaDB are essential for full-stack development.
#   All configured to auto-start on boot.
################################################################################

section_databases() {
    print_section "DATABASE SERVERS (POSTGRESQL, MARIADB)"

    print_info "Installing PostgreSQL server and client..."
    dnf install -y --skip-unavailable postgresql postgresql-server postgresql-contrib

    # Check if PostgreSQL database is already initialized
    if [[ ! -d /var/lib/pgsql/data ]]; then
        print_info "Initializing PostgreSQL database..."
        set +e
        postgresql-setup initdb
        initdb_result=$?
        set -e

        if [[ $initdb_result -eq 0 ]]; then
            print_success "PostgreSQL database initialized"
        else
            print_warning "PostgreSQL initialization encountered an issue, continuing..."
        fi
    else
        print_info "PostgreSQL database already initialized, skipping initdb"
    fi

    systemctl enable postgresql

    # Start PostgreSQL with timeout
    print_info "Starting PostgreSQL..."
    timeout 30 systemctl start postgresql || print_warning "PostgreSQL start timed out or failed, continuing..."
    sleep 2  # Give it a moment to stabilize
    print_success "PostgreSQL installed and configured"

    print_info "Installing MariaDB server..."
    dnf install -y --skip-unavailable mariadb-server

    systemctl enable mariadb

    # Start MariaDB with timeout
    print_info "Starting MariaDB..."
    timeout 30 systemctl start mariadb || print_warning "MariaDB start timed out or failed, continuing..."
    sleep 2  # Give it a moment to stabilize
    print_success "MariaDB installed and configured"

    print_warning "SECURITY: MariaDB root password is not set. For security, run: sudo mysql_secure_installation"

    print_info "Quick start commands:"
    echo "  PostgreSQL:"
    echo "    psql -U postgres                    # Connect to PostgreSQL"
    echo "    sudo systemctl status postgresql    # Check status"
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

    # Get the actual user's home directory
    USER_HOME=$(eval echo "~$SUDO_USER")

    print_info "Installing Dev Containers extension..."
    sudo -u "$SUDO_USER" code --install-extension ms-vscode-remote.remote-containers || print_warning "Dev Containers extension installation may require VS Code to be run manually"
    print_success "Dev Containers extension installation attempted"

    print_info "Disabling telemetry..."
    sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/Code/User"
    cat >> "$USER_HOME/.config/Code/User/settings.json" << 'EOF'
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
#              SECTION 15: FLUTTER SDK
#
#   Flutter is Google's UI framework for building multi-platform apps.
#   Cloned from official Flutter GitHub stable branch.
#   Requires Android Studio for Android development (manual installation).
#   Reference: https://docs.flutter.dev/install/manual
################################################################################

section_flutter() {
    print_section "FLUTTER SDK"

    print_info "Setting up Brave as CHROME_EXECUTABLE..."
    export CHROME_EXECUTABLE=/var/lib/flatpak/exports/bin/com.brave.Browser

    # CRITICAL FIX: Use actual user home, not root's home
    REAL_HOME=$(eval echo ~$SUDO_USER)
    FLUTTER_HOME="$REAL_HOME/.flutter"
    BASHRC="$REAL_HOME/.bashrc"

    print_info "Setting up Flutter SDK from GitHub stable branch..."
    print_info "User home: $REAL_HOME"
    print_info "Flutter home: $FLUTTER_HOME"

    if [[ -d "$FLUTTER_HOME" ]]; then
        print_info "Flutter directory exists, checking if it's a valid Git repository..."

        # Check if it's a valid git repo with .git directory
        if [[ -d "$FLUTTER_HOME/.git" ]]; then
            print_info "Valid Flutter Git repository found, updating to latest stable..."

            set +e
            sudo -u "$SUDO_USER" git -C "$FLUTTER_HOME" fetch origin stable 2>/dev/null
            fetch_result=$?

            if [[ $fetch_result -eq 0 ]]; then
                sudo -u "$SUDO_USER" git -C "$FLUTTER_HOME" checkout stable
                sudo -u "$SUDO_USER" git -C "$FLUTTER_HOME" pull origin stable
                pull_result=$?

                if [[ $pull_result -eq 0 ]]; then
                    print_success "Flutter updated to latest stable"
                else
                    print_warning "Flutter update encountered an issue, continuing..."
                fi
            else
                print_warning "Could not fetch Flutter updates (network issue?), continuing with existing install..."
            fi
            set -e

        else
            print_warning "Flutter directory exists but is not a valid Git repository, removing and re-cloning..."

            # Force remove the directory
            set +e
            sudo -u "$SUDO_USER" rm -rf "$FLUTTER_HOME"
            rm_result=$?
            set -e

            if [[ $rm_result -eq 0 ]]; then
                sleep 1  # Give filesystem time to catch up

                print_info "Cloning Flutter from GitHub stable branch..."
                set +e
                sudo -u "$SUDO_USER" git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_HOME"
                clone_result=$?
                set -e

                if [[ $clone_result -ne 0 ]]; then
                    print_error "Failed to clone Flutter repository"
                    return 1
                fi
                print_success "Flutter cloned successfully"
            else
                print_error "Failed to remove invalid Flutter directory"
                return 1
            fi
        fi

    else
        print_info "Cloning Flutter from GitHub stable branch..."

        # Create parent directory with correct permissions
        sudo -u "$SUDO_USER" mkdir -p "$REAL_HOME"

        set +e
        sudo -u "$SUDO_USER" git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_HOME"
        clone_result=$?
        set -e

        if [[ $clone_result -ne 0 ]]; then
            print_error "Failed to clone Flutter repository"
            return 1
        fi
        print_success "Flutter cloned successfully"
    fi

    # Verify flutter binary exists
    if [[ ! -f "$FLUTTER_HOME/bin/flutter" ]]; then
        print_error "Flutter binary not found at $FLUTTER_HOME/bin/flutter"
        return 1
    fi
    print_success "Flutter binary verified"

    # Add Flutter to PATH in user's ~/.bashrc
    if ! grep -q "export PATH.*\.flutter/bin" "$BASHRC" 2>/dev/null; then
        echo 'export PATH="$HOME/.flutter/bin:$PATH"' >> "$BASHRC"
        print_success "Flutter added to PATH in ~/.bashrc"
    else
        print_info "Flutter PATH already configured in ~/.bashrc"
    fi

    # Verify installation by running as the actual user
    print_info "Verifying Flutter installation..."

    set +e
    version_output=$(sudo -u "$SUDO_USER" "$FLUTTER_HOME/bin/flutter" --version 2>&1)
    version_result=$?
    set -e

    if [[ $version_result -eq 0 ]]; then
        print_success "Flutter SDK installed successfully"
        echo "$version_output"
    else
        print_warning "Flutter installation may need shell restart to verify"
        echo "Error: $version_output"
    fi

    print_success "Flutter SDK setup complete!"
    print_info "Next steps:"
    echo "  1. RESTART SHELL: source ~/.bashrc or open new terminal"
    echo "  2. Run: flutter doctor (shows missing dependencies)"
    echo "  3. Install Android Studio: https://developer.android.com/studio"
    echo "  4. Create Flutter app: flutter create my_app"
    print_info "Keep Flutter updated:"
    echo "  Run 'flutter upgrade' periodically for latest stable version"
}


################################################################################
#              SECTION 16: INSTALLATION COMPLETE - SUMMARY
################################################################################

section_summary() {
    print_section "INSTALLATION COMPLETE"

    print_success "Installed Components:"
    echo "  Build Tools  : gcc, make, cmake, git, git-lfs"
    echo "  Java         : Java 21 LTS (default) + Java 25"
    echo "  Build Tools  : Maven, Spring Boot CLI"
    echo "  VPN          : Mullvad VPN"
    echo "  Node.js      : NVM with Node LTS (npm, npx)"
    echo "  Languages    : Rust (rustup), Python 3 (pip, venv)"
    echo "  Containers   : Docker, Docker Compose"
    echo "  Databases    : PostgreSQL, MariaDB"
    echo "  Editor       : VS Code (Microsoft repo) + Dev Containers"
    echo "  Apps         : 20+ Flatpak apps (Godot, HandBrake, FreeTube, ...)"
    echo ""

    print_warning "Restart your shell before using NVM, Docker, and updated PATH:"
    echo "  source ~/.bashrc   OR   exec bash   OR   open a new terminal"
    echo ""

    print_info "Switch Java versions:"
    echo "  sudo update-alternatives --config java"
    echo "  sudo update-alternatives --config javac"
    echo "  Default: Java 21 | Available: Java 25"
    echo ""

    print_info "Git configuration:"
    echo "  Username : $GIT_USERNAME"
    echo "  Email    : $GIT_EMAIL"
    echo "  Update   : git config --global user.name \"Name\""
    echo ""

    print_info "System hostname: $FINAL_HOSTNAME"
    echo ""

    print_info "VPN: Mullvad VPN installed. Launch with: mullvad"
    echo ""

    print_info "Database quick-connect:"
    echo "  PostgreSQL : psql -U postgres"
    echo "  MariaDB    : sudo mysql -u root"
    echo ""

    print_warning "Security notices:"
    echo "  1. Docker group = root-level access. Only add trusted users."
    echo "     Rootless Docker: https://docs.docker.com/engine/security/rootless/"
    echo "  2. MariaDB root password not set. Run: sudo mysql_secure_installation"
    echo ""

    print_info "Environment variables (in ~/.bashrc):"
    echo "  JAVA_HOME=/usr/lib/jvm/java-21-openjdk"
    echo "  M2_HOME=/usr/share/maven"
    echo ""

    print_warning "Manual steps required after reboot:"
    echo ""
    echo "  [PostgreSQL - if initialization failed]"
    echo "    sudo /usr/bin/postgresql-setup --initdb"
    echo "    sudo systemctl start postgresql"
    echo "    sudo journalctl -u postgresql -n 30   # check logs if needed"
    echo ""
    echo "  [MariaDB - secure the installation]"
    echo "    sudo mysql_secure_installation"
    echo ""
    echo "  [JetBrains Toolbox - manual install]"
    echo "    https://www.jetbrains.com/toolbox/"
    echo ""
    echo "  [Android Studio - manual install, needed for Flutter/React Native]"
    echo "    https://developer.android.com/studio"
    echo ""
    echo "  [Flutter - after shell restart]"
    echo "    flutter doctor"
    echo ""
    echo "  [SSH key for GitHub/GitLab]"
    echo "    ssh-keygen -t ed25519"
    echo ""

    print_success "Setup complete. Happy coding!"
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
    section_flutter
    section_git_config
    section_customization
    section_summary
}

# Run main function
main
