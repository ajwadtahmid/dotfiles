#!/bin/bash

################################################################################
#                   FEDORA DEVELOPER SETUP SCRIPT
#
#   An installation script for Fedora Linux
#
#   Usage: chmod +x install.sh && bash install.sh
#   Tested on: Fedora 43
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
#               SECTION 2: ESSENTIAL SOFTWARE
################################################################################

section_build_tools() {
    print_section "ESSENTIAL SOFTWARE"

    print_info "Installing essential software..."
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
        steam \
        gnome-disk-utility \
        mangohud \
        goverlay

    print_info "Initializing Git LFS..."
    sudo -Hu "$SUDO_USER" git lfs install
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
        com.usebruno.Bruno \
        org.godotengine.Godot \
        fr.handbrake.ghb \
        net.cozic.joplin_desktop \
        net.mullvad.MullvadBrowser

    print_success "Core Flatpak applications installed"
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
#              SECTION 4: MULLVAD VPN
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
#              SECTION 5: ZED EDITOR & ATUIN
#
#   Zed is a minimal code editor crafted for speed.
#   Install from official Zed repository for security and automatic updates.
################################################################################

section_zed_atuin() {
    print_section "ZED EDITOR"

    if sudo -Hu "$SUDO_USER" bash -c 'command -v zed >/dev/null 2>&1 || [ -x "$HOME/.local/bin/zed" ]'; then
        print_info "Zed already installed — skipping"
    else
        print_info "Installing Zed editor..."
        sudo -Hu "$SUDO_USER" bash -c 'curl -fsSL https://zed.dev/install.sh | bash'
        print_success "Zed installed"
    fi

    print_section "ATUIN SHELL HISTORY MANAGER"

    if sudo -Hu "$SUDO_USER" bash -c 'command -v atuin >/dev/null 2>&1 || [ -x "$HOME/.local/bin/atuin" ]'; then
        print_info "Atuin already installed — skipping"
    else
        print_info "Installing Atuin shell history manager..."
        sudo -Hu "$SUDO_USER" bash -c 'curl --proto "=https" --tlsv1.2 -LsSf https://setup.atuin.sh | sh'
        print_success "Atuin installed"
    fi


}

################################################################################
#              SECTION 6: GIT CONFIGURATION
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
    print_success "Git configured"

    print_info "Git configuration:"
    sudo -Hu "$SUDO_USER" git config --global --list | grep -E "user\.|pull\.|init\."

    print_info "To update Git config later, run:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
}

################################################################################
#              SECTION 7: DEV TOOLS
#
#   Installs development runtimes, languages, and local database services:
#     - NVM + Node LTS, TypeScript, React Native, Expo CLI
#     - Go, Flutter + Dart, Rustup
#     - Java 21, Maven, Gradle, Spring Boot CLI (via SDKMAN)
#     - PostgreSQL, MariaDB, MongoDB (local services)
#
#   SECURITY NOTE: Database services are configured for local development only.
#   Change default credentials before exposing to any network.
################################################################################

section_dev_tools() {
    print_section "DEV TOOLS"

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

    print_info "Installing Node LTS via NVM..."
    sudo -Hu "$SUDO_USER" bash -c \
        'export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" &&
         nvm install --lts && nvm use --lts && nvm alias default node'
    print_success "Node LTS installed"

    # ── React Native + Expo CLI ───────────────────────────────────────────────
    print_info "Installing Expo CLI..."
    sudo -Hu "$SUDO_USER" bash -c \
        'export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" &&
         npm install -g @expo/cli'
    print_success "Expo CLI installed"

    # ── Go ────────────────────────────────────────────────────────────────────
    print_info "Installing Go..."
    dnf install -y golang
    print_success "Go installed"

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

    # Add Flutter to PATH via ~/.bashrc (idempotent: only append if not already there)
    BASHRC="$USER_HOME/.bashrc"
    FLUTTER_LINE='export PATH="$PATH:$HOME/.flutter/bin"'
    if ! sudo -Hu "$SUDO_USER" grep -Fxq "$FLUTTER_LINE" "$BASHRC" 2>/dev/null; then
        echo "" | sudo -Hu "$SUDO_USER" tee -a "$BASHRC" > /dev/null
        echo "# Flutter SDK" | sudo -Hu "$SUDO_USER" tee -a "$BASHRC" > /dev/null
        echo "$FLUTTER_LINE" | sudo -Hu "$SUDO_USER" tee -a "$BASHRC" > /dev/null
        print_success "Flutter added to ~/.bashrc"
    else
        print_info "Flutter PATH already in ~/.bashrc — skipping"
    fi

    sudo -Hu "$SUDO_USER" bash -c "export PATH=\"\$PATH:$FLUTTER_DIR/bin\" && flutter precache"

    export CHROME_EXECUTABLE=/var/lib/flatpak/exports/bin/com.brave.Browser

    print_success "Flutter + Dart installed and Brave set as CHROME_EXECUTABLE"

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

    # ── Java 21 + Maven ───────────────────────────────────────────────────────
    print_info "Installing Java 21 and Maven..."
    dnf install -y java-21-openjdk java-21-openjdk-devel maven
    print_success "Java 21 and Maven installed"

    # ── SDKMAN → Gradle + Spring Boot CLI ────────────────────────────────────
    print_info "Installing SDKMAN..."
    if [[ -d "$USER_HOME/.sdkman" ]]; then
        print_info "SDKMAN already installed — skipping installer"
    else
        sudo -Hu "$SUDO_USER" bash -c 'curl -s "https://get.sdkman.io" | bash'
    fi
    sudo -Hu "$SUDO_USER" bash -c \
        'source "$HOME/.sdkman/bin/sdkman-init.sh" && \
         echo "n" | sdk install gradle && \
         echo "n" | sdk install springboot'
    print_success "Gradle and Spring Boot CLI installed via SDKMAN"

    # ── PostgreSQL ────────────────────────────────────────────────────────────
    print_info "Installing PostgreSQL..."
    dnf install -y postgresql postgresql-server
    if [[ -f /var/lib/pgsql/data/PG_VERSION ]]; then
        print_info "PostgreSQL cluster already initialized — skipping initdb"
    else
        postgresql-setup --initdb
    fi
    systemctl enable postgresql
    systemctl start postgresql
    print_info "Creating PostgreSQL dev account (if missing)..."
    sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='dev'" | grep -q 1 || \
        sudo -u postgres psql -c "CREATE USER dev WITH PASSWORD 'dev';"
    sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='devdb'" | grep -q 1 || \
        sudo -u postgres psql -c "CREATE DATABASE devdb OWNER dev;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE devdb TO dev;"
    print_success "PostgreSQL installed — user: dev, password: dev, db: devdb"

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
#              SECTION 8: DOCKER & DOCKER COMPOSE
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
        --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
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
#              SECTION 9: SYSTEM CUSTOMIZATION
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
#              SECTION 10: DEV CONTAINERS
#
#   Installs the devcontainer CLI and scaffolds a reusable template at
#   ~/.dotfiles/devcontainer-template/.devcontainer/ containing:
#     - devcontainer.json  (VS Code extensions, port forwarding, remoteUser)
#     - docker-compose.yml (app + PostgreSQL + MySQL + MongoDB)
#
#   To use the template in a project:
#     cp -r ~/.dotfiles/devcontainer-template/.devcontainer /path/to/your/project/
#   Then open the project in VS Code and run:
#     "Dev Containers: Reopen in Container"
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

    # ── devcontainer.json ────────────────────────────────────────────────────
    print_info "Writing devcontainer.json..."
    cat > "$TEMPLATE_DIR/devcontainer.json" << 'DEVCONTAINER_JSON'
{
  "name": "Universal Dev Environment",

  // Use docker-compose to start the dev container + all database services together
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",

  // NOTE: .ssh and .gitconfig mounts are defined in docker-compose.yml
  // under the "app" service volumes. Do NOT duplicate them here — when VS Code
  // uses dockerComposeFile mode it merges both, causing mount conflicts.
  // If you switch to a single-container setup (no docker-compose), uncomment these:
  // "mounts": [
  //   "source=${localEnv:HOME}/.ssh,target=/home/dev/.ssh,type=bind,readonly",
  //   "source=${localEnv:HOME}/.gitconfig,target=/home/dev/.gitconfig,type=bind,readonly"
  // ],

  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },

  "customizations": {
    "vscode": {
      "extensions": [
        // General
        "eamodio.gitlens",
        "streetsidesoftware.code-spell-checker",
        "EditorConfig.EditorConfig",

        // Python
        "ms-python.python",
        "ms-python.vscode-pylance",
        "charliermarsh.ruff",

        // JS / TS
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "bradlc.vscode-tailwindcss",

        // Rust
        "rust-lang.rust-analyzer",
        "tamasfe.even-better-toml",

        // Go
        "golang.go",

        // Java / Kotlin
        "redhat.java",
        "vscjava.vscode-java-pack",
        "fwcd.kotlin",

        // Scala
        "scala-lang.scala",
        "scalameta.metals",

        // Flutter / Dart
        "Dart-Code.dart-code",
        "Dart-Code.flutter",

        // C / C++
        "ms-vscode.cpptools",
        "ms-vscode.cmake-tools",

        // Docker / Infra
        "ms-azuretools.vscode-docker",
        "HashiCorp.terraform",
        "redhat.ansible",

        // Swift
        "sswg.swift-lang",

        // Ruby
        "Shopify.ruby-lsp",

        // PHP
        "bmewburn.vscode-intelephense-client",

        // Lua
        "sumneko.lua",

        // .NET / C#
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash",
        "editor.formatOnSave": true,
        "editor.rulers": [100],
        "python.defaultInterpreterPath": "/home/dev/.pyenv/shims/python"
      }
    }
  },

  "remoteUser": "dev",

  // Runs on the HOST before the container starts. Ensures ~/.gitconfig and
  // ~/.ssh exist. Without this, Docker bind-mounts a non-existent path as an
  // empty directory, breaking git inside the container.
  "initializeCommand": "[ -f ~/.gitconfig ] || (mkdir -p ~/.ssh && touch ~/.gitconfig)",

  "runArgs": ["--shm-size=2gb"],

  // Ports forwarded from the container to the host.
  // Database ports (5432, 3306, etc.) are on separate service containers —
  // forwarding is handled by docker-compose "ports:" mappings.
  "forwardPorts": [
    3000,   // React / Next.js / Vue / Svelte
    4000,   // Misc backend / Apollo GraphQL
    4173,   // Vite preview
    4200,   // Angular CLI
    4321,   // Astro
    5000,   // Flask / ASP.NET Core HTTP
    5001,   // ASP.NET Core HTTPS
    5173,   // Vite dev server
    6006,   // Storybook
    7000,   // ASP.NET .NET 6+ HTTP
    8000,   // Django / FastAPI
    8080,   // General HTTP / Spring Boot
    8081,   // Metro bundler (React Native)
    8888,   // Jupyter
    9000,   // Play Framework (Scala)
    9100,   // Flutter DevTools
    9229,   // Node.js debugger
    19000,  // Expo
    19001,  // Expo DevTools
    19002,  // Expo web
    5432,   // PostgreSQL
    3306,   // MySQL
    6379,   // Redis
    27017   // MongoDB
  ],

  "portsAttributes": {
    "3000": { "label": "Frontend" },
    "4173": { "label": "Vite Preview" },
    "4200": { "label": "Angular" },
    "4321": { "label": "Astro" },
    "5000": { "label": "Flask / ASP.NET" },
    "5001": { "label": "ASP.NET HTTPS" },
    "5173": { "label": "Vite" },
    "6006": { "label": "Storybook" },
    "7000": { "label": "ASP.NET (.NET 6+)" },
    "8000": { "label": "Backend" },
    "8080": { "label": "HTTP / Spring Boot" },
    "8081": { "label": "Metro (React Native)" },
    "9000": { "label": "Play Framework" },
    "9100": { "label": "Flutter DevTools" },
    "9229": { "label": "Node Debugger" },
    "19000": { "label": "Expo" },
    "19001": { "label": "Expo DevTools" },
    "19002": { "label": "Expo Web" },
    "5432": { "label": "PostgreSQL" },
    "3306": { "label": "MySQL" },
    "6379": { "label": "Redis" },
    "27017": { "label": "MongoDB" }
  }
}
DEVCONTAINER_JSON
    print_success "devcontainer.json written"

    # ── docker-compose.yml ───────────────────────────────────────────────────
    print_info "Writing docker-compose.yml..."
    cat > "$TEMPLATE_DIR/docker-compose.yml" << 'DOCKER_COMPOSE_YML'
# SECURITY WARNING: Credentials below are for LOCAL DEVELOPMENT ONLY.
# Never use them in production, staging, or any network-exposed environment.
services:

  # ─── Dev container ──────────────────────────────────────────────────────────
  app:
    image: ghcr.io/ajwadtahmid/devenv:latest  # <-- replace with your username
    volumes:
      - ..:/workspace:cached               # Project root (one level up from .devcontainer/)
      - ~/.ssh:/home/dev/.ssh:ro           # SSH keys for git over SSH
      - ~/.gitconfig:/home/dev/.gitconfig:ro
    command: sleep infinity                # Keep the container alive
    environment:
      - POSTGRES_URL=postgresql://dev:dev@postgres:5432/devdb
      - MYSQL_URL=mysql://dev:dev@mysql:3306/devdb
      - REDIS_URL=redis://redis:6379
      - MONGO_URL=mongodb://dev:dev@mongo:27017/devdb
      - SQLITE_PATH=/workspace/db.sqlite3
    depends_on:
      postgres:
        condition: service_healthy
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      mongo:
        condition: service_healthy

  # ─── PostgreSQL ─────────────────────────────────────────────────────────────
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: devdb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dev -d devdb"]
      interval: 5s
      timeout: 5s
      retries: 5

  # ─── MySQL ──────────────────────────────────────────────────────────────────
  mysql:
    image: mysql:8.4
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: rootdev
      MYSQL_USER: dev
      MYSQL_PASSWORD: dev
      MYSQL_DATABASE: devdb
    volumes:
      - mysql_data:/var/lib/mysql
    ports:
      - "127.0.0.1:3306:3306"
    healthcheck:
      # Using MYSQL_PWD avoids the "password on command line is insecure" warning
      test: ["CMD-SHELL", "MYSQL_PWD=dev mysqladmin ping -h localhost -u dev"]
      interval: 5s
      timeout: 5s
      retries: 5

  # ─── Redis ──────────────────────────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass dev
    restart: unless-stopped
    volumes:
      - redis_data:/data
    ports:
      - "127.0.0.1:6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  # ─── MongoDB ────────────────────────────────────────────────────────────────
  mongo:
    image: mongo:8
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: dev
      MONGO_INITDB_ROOT_PASSWORD: dev
      MONGO_INITDB_DATABASE: devdb
    volumes:
      - mongo_data:/data/db
    ports:
      - "127.0.0.1:27017:27017"
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')", "--quiet"]
      interval: 5s
      timeout: 5s
      retries: 5

# ─── Named volumes ─────────────────────────────────────────────────────────────
# To wipe a database and start fresh, delete its volume:
#   docker volume rm .devcontainer_postgres_data
volumes:
  postgres_data:
  mysql_data:
  redis_data:
  mongo_data:
DOCKER_COMPOSE_YML
    print_success "docker-compose.yml written"

    chown -R "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.dotfiles"
    print_success "Ownership set for ~/.dotfiles"

    print_info "To use: cp -r ~/.dotfiles/devcontainer-template/.devcontainer /your/project/"
    print_info "Then in VS Code: 'Dev Containers: Reopen in Container'"
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
    section_zed_atuin
    section_git_config
    section_dev_tools
    section_docker
    section_customization
    section_devcontainers
    section_summary
}

# Run main function
main
