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
        steam \
        gnome-disk-utility \
        mangohud \
        goverlay \

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
#              SECTION 5: ZED EDITOR
#
#   Zed is a minimal code editor crafted for speed.
#   Install from official Zed repository for security and automatic updates.
################################################################################

section_zed_editor() {
    print_section "ZED EDITOR"

    print_info "Installing Zed editor..."
    sudo -u "$SUDO_USER" bash -c 'curl -fsSL https://zed.dev/install.sh | bash'
    print_success "Zed installed"
}


################################################################################
#              SECTION 6: PYTHON 3 WITH PIP & VENV
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
#              SECTION 7: DOCKER & DOCKER COMPOSE
#
#   Docker enables containerized development and testing.
#   Auto-start daemon is configured to run on boot.
#   Dev Containers extension for VS Code & Zed allows container-based development.
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
#              SECTION 8: GIT CONFIGURATION
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
#              SECTION 9: SYSTEM CUSTOMIZATION
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
#              SECTION 10: DEV CONTAINERS
#
#   Installs the devcontainer CLI and scaffolds a reusable template at
#   ~/.dotfiles/devcontainer-template/.devcontainer/ containing:
#     - devcontainer.json  (VS Code extensions, port forwarding, remoteUser)
#     - docker-compose.yml (app + PostgreSQL + MySQL + Redis + MongoDB)
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
  "initializeCommand": "[ -d ~/.gitconfig ] && rm -rf ~/.gitconfig; mkdir -p ~/.ssh; touch ~/.gitconfig",

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
    section_zed_editor
    section_python
    section_docker
    section_git_config
    section_customization
    section_devcontainers
    section_summary
}

# Run main function
main
