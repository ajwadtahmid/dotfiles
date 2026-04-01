#!/usr/bin/env bash
# ─── Strict mode ──────────────────────────────────────────────────────────────
# -e  exit immediately if any command fails
# -u  treat unset variables as errors (catches typos like $HOEM)
# -o pipefail  if any command in a pipeline fails, the whole pipeline fails
set -euo pipefail

echo "═══════════════════════════════════════════"
echo "  Dev Environment Bootstrap — Fedora"
echo "═══════════════════════════════════════════"

# ─── System packages ──────────────────────────────────────────────────────────
# These are installed via dnf (Fedora's package manager).
# stow         — symlink manager for dotfiles (see Part 1)
# gcc, g++, clang, cmake, make — C/C++ toolchain
# *-devel packages — header files needed to compile Python (pyenv) and Tauri
# qt6-*        — Qt6 headers for C++ Qt applications
# lua          — Lua runtime and headers
# docker-ce    — Docker Engine (full daemon, not Podman)
# android-tools — adb for React Native / Flutter device connections
echo "→ Installing system packages..."
sudo dnf install -y \
  git curl wget stow \
  gcc gcc-c++ clang cmake make ninja-build \
  openssl-devel zlib-devel bzip2-devel readline-devel \
  sqlite-devel libffi-devel xz-devel tk-devel \
  qt6-qtbase-devel qt6-qtdeclarative-devel \
  webkit2gtk4.1-devel libayatana-appindicator-gtk3-devel \
  lua lua-devel \
  android-tools

# ─── Docker ───────────────────────────────────────────────────────────────────
# Install Docker CE from the official Docker repo (not Podman).
# We check if it's already installed to avoid unnecessary dnf calls.
echo "→ Setting up Docker..."
if ! command -v docker &>/dev/null; then
  sudo dnf config-manager addrepo \
    --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
  sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
# Enable Docker to start automatically and start it now if not already running
sudo systemctl enable --now docker
# Add current user to the docker group so docker commands don't require sudo.
# This takes effect on next login — see note at the end of the script.
sudo usermod -aG docker "$USER"

# ─── pyenv + Python 3.12 ──────────────────────────────────────────────────────
# pyenv compiles Python from source, so you get an exact version rather than
# whatever Fedora packages. The "if" check makes this step idempotent.
echo "→ Installing pyenv + Python..."
if [ ! -d "$HOME/.pyenv" ]; then
  curl https://pyenv.run | bash
fi
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
# --skip-existing means pyenv won't recompile if this version is already built
pyenv install --skip-existing 3.12.0
pyenv global 3.12.0
pip install --upgrade pip uv pipx
pipx install poetry

# ─── fnm + Node.js LTS ────────────────────────────────────────────────────────
echo "→ Installing fnm + Node LTS..."
if ! command -v fnm &>/dev/null; then
  curl -fsSL https://fnm.vercel.app/install | bash
fi
# fnm installs to ~/.local/share/fnm — add to PATH for this session
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env)"
fnm install --lts
fnm use lts-latest
npm install -g typescript pnpm yarn

# ─── Bun ──────────────────────────────────────────────────────────────────────
echo "→ Installing Bun..."
# Bun's installer is idempotent — safe to run even if Bun is already installed
curl -fsSL https://bun.sh/install | bash

# ─── Rust ─────────────────────────────────────────────────────────────────────
echo "→ Installing Rust..."
if ! command -v rustup &>/dev/null; then
  # -y accepts all defaults non-interactively (no prompts)
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
source "$HOME/.cargo/env"
rustup update stable
cargo install cargo-watch cargo-edit

# ─── Go ───────────────────────────────────────────────────────────────────────
echo "→ Installing Go..."
GO_VERSION="1.23.0"
if [ ! -d "/usr/local/go" ]; then
  # Download and extract directly into /usr/local — the standard Go install path
  wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
  sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
  rm "go${GO_VERSION}.linux-amd64.tar.gz"
fi

# ─── SDKMAN → Java, Kotlin, Scala, Maven, Gradle ─────────────────────────────
echo "→ Installing SDKMAN + JVM tools..."
if [ ! -d "$HOME/.sdkman" ]; then
  curl -s "https://get.sdkman.io" | bash
fi
source "$HOME/.sdkman/bin/sdkman-init.sh"
# "sdk install X" is idempotent — it skips if the tool is already installed
sdk install java 21.0.3-tem   # Eclipse Temurin — the most widely used OpenJDK build
sdk install kotlin
sdk install scala
sdk install maven
sdk install gradle

# ─── Swift ────────────────────────────────────────────────────────────────────
echo "→ Installing swiftenv + Swift..."
if [ ! -d "$HOME/.swiftenv" ]; then
  git clone https://github.com/kylef/swiftenv.git "$HOME/.swiftenv"
fi
export SWIFTENV_ROOT="$HOME/.swiftenv"
export PATH="$SWIFTENV_ROOT/bin:$PATH"
eval "$(swiftenv init -)"
# "|| true" prevents the script from exiting if Swift 5.10 is already installed
swiftenv install 5.10 || true
swiftenv global 5.10

# ─── Flutter + Dart ───────────────────────────────────────────────────────────
echo "→ Installing Flutter..."
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi
export PATH="$PATH:$HOME/flutter/bin"
# precache downloads the Linux engine binaries so first-run is faster
flutter precache
# flutter doctor checks your environment and reports any missing dependencies
flutter doctor

# ─── Terraform ────────────────────────────────────────────────────────────────
echo "→ Installing Terraform..."
if ! command -v terraform &>/dev/null; then
  sudo dnf config-manager addrepo \
    --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
  sudo dnf install -y terraform
fi

# ─── Ansible ──────────────────────────────────────────────────────────────────
# Installed via pipx so it has its own isolated Python environment
echo "→ Installing Ansible..."
pipx install ansible-core || pipx upgrade ansible-core

# ─── Stow dotfiles ────────────────────────────────────────────────────────────
# Create symlinks from ~/.dotfiles into ~ for each package listed.
# If a symlink already exists and points to the right place, stow skips it.
# If a real file exists at the target (e.g. a pre-existing ~/.bashrc), stow
# will error — you must remove or back up the original file first.
echo "→ Symlinking dotfiles..."
cd ~/.dotfiles
stow bash git zed

echo ""
echo "✓ Done!"
echo ""
echo "  Next steps:"
echo "  1. Run: source ~/.bashrc"
echo "  2. Log out and back in so the docker group takes effect"
echo "  3. Verify Docker works: docker run hello-world"
