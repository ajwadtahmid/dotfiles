#!/usr/bin/env bash
# ─── Strict mode ──────────────────────────────────────────────────────────────
# -e  exit immediately if any command fails
# -u  treat unset variables as errors (catches typos like $HOEM)
# -o pipefail  if any command in a pipeline fails, the whole pipeline fails
set -euo pipefail

echo "═══════════════════════════════════════════"
echo "  Dev Environment Bootstrap — Fedora 43"
echo "═══════════════════════════════════════════"

# ─── System packages ──────────────────────────────────────────────────────────
# FIX: webkit2gtk4.1-devel → webkitgtk6.0-devel (renamed in Fedora 41+)
# FIX: libayatana-appindicator-gtk3-devel → libappindicator-gtk3-devel
#      (the ayatana variant is a Debian/Ubuntu package name, not Fedora)
echo "→ Installing system packages..."
sudo dnf install -y \
  git curl wget stow \
  gcc gcc-c++ clang cmake make ninja-build \
  openssl-devel zlib-devel bzip2-devel readline-devel \
  sqlite-devel libffi-devel xz-devel tk-devel \
  qt6-qtbase-devel qt6-qtdeclarative-devel \
  webkitgtk6.0-devel libappindicator-gtk3-devel \
  lua lua-devel \
  android-tools

# ─── Docker ───────────────────────────────────────────────────────────────────
# FIX: "dnf config-manager addrepo --from-repofile" is dnf4 syntax.
#      On Fedora 41+ (dnf5), the correct flag is "--add-repo <url>".
echo "→ Setting up Docker..."
if ! command -v docker &>/dev/null; then
  sudo dnf config-manager --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo
  sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
# Enable Docker to start automatically and start it now if not already running
sudo systemctl enable --now docker
# Add current user to the docker group so docker commands don't require sudo.
# This takes effect on next login — see note at the end of the script.
sudo usermod -aG docker "$USER"

# ─── pyenv + Python 3.12 ──────────────────────────────────────────────────────
# FIX: 3.12.0 → 3.12.13 (latest 3.12.x as of April 2026).
#      3.12.0 fails to build on Fedora 43 due to a Tcl_Size type mismatch
#      introduced in Tcl 8.7/9.0 that ships with Fedora 41+.
echo "→ Installing pyenv + Python..."
if [ ! -d "$HOME/.pyenv" ]; then
  curl https://pyenv.run | bash
fi
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
pyenv install --skip-existing 3.12.13
pyenv global 3.12.13
pip install --upgrade pip uv pipx
pipx install poetry

# ─── fnm + Node.js LTS ────────────────────────────────────────────────────────
# FIX: The fnm binary lives in ~/.local/share/fnm (confirmed by the installer
#      output), not ~/.local/bin. The previous fix was wrong.
# FIX: "fnm env" must be called with "--shell bash" when running inside a
#      non-interactive script, otherwise fnm won't set up the environment.
echo "→ Installing fnm + Node LTS..."
if ! command -v fnm &>/dev/null; then
  curl -fsSL https://fnm.vercel.app/install | bash
fi
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --shell bash)"
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
# FIX: 1.23.0 → 1.26.1 (latest stable as of April 2026; 1.23.x is EOL).
# FIX: Hardcoded "linux-amd64" replaced with dynamic arch detection so the
#      script works correctly on both x86_64 and aarch64 machines.
# FIX: Added $HOME/go/bin to PATH so tools installed via "go install" are found.
echo "→ Installing Go..."
GO_VERSION="1.26.1"
GOARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
if [ ! -d "/usr/local/go" ]; then
  wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz"
  sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-${GOARCH}.tar.gz"
  rm "go${GO_VERSION}.linux-${GOARCH}.tar.gz"
fi
export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"

# ─── SDKMAN → Java, Kotlin, Scala, Maven, Gradle ─────────────────────────────
# FIX: "21.0.3-tem" → "21-tem". SDKMAN periodically prunes specific patch
#      build IDs from its candidate list; using the channel alias "21-tem"
#      always resolves to the current stable Temurin 21.x release.
echo "→ Installing SDKMAN + JVM tools..."
# FIX: Disable set -u for the ENTIRE SDKMAN block — install, source, AND sdk
# commands. SDKMAN's sdkman-init.sh self-update routine calls sdkman-install.sh
# with positional args ($3) that may be unset, crashing the script even when
# SDKMAN is already installed. The sdk shell function itself also references
# unbound variables internally. set +u must stay active until all sdk calls
# are done.
set +u
if [ ! -d "$HOME/.sdkman" ]; then
  curl -s "https://get.sdkman.io" | bash
fi
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21-tem
sdk install kotlin
sdk install scala
sdk install maven
sdk install gradle
set -u

# ─── Swift ────────────────────────────────────────────────────────────────────
# Using the official Fedora-packaged swift-lang RPM. It is maintained by the
# Fedora project specifically for your distro, installs cleanly via dnf with no
# interactive prompts or unsupported-platform workarounds, and is updated
# automatically alongside the rest of the system with "dnf upgrade".
# Fedora 43 ships Swift 6.2 — one minor version behind upstream, fine for
# all practical purposes.
echo "→ Installing Swift..."
sudo dnf install -y swift-lang

# ─── Flutter + Dart ───────────────────────────────────────────────────────────
echo "→ Installing Flutter..."
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi
export PATH="$PATH:$HOME/flutter/bin"
# FIX: Point Flutter's Chrome tooling at Flatpak Brave Browser.
# Without this, "flutter run -d chrome" and flutter doctor both error with
# "Cannot find Chrome executable at google-chrome".
export CHROME_EXECUTABLE=/var/lib/flatpak/exports/bin/com.brave.Browser
# precache downloads the Linux engine binaries so first-run is faster
flutter precache
# FIX: "|| true" prevents the Android SDK warning from aborting the script.
# Android Studio is not installed here — that warning is expected and harmless.
flutter doctor || true

# ─── Terraform ────────────────────────────────────────────────────────────────
# FIX: Fedora 43 uses dnf5 whose config-manager syntax is:
#        addrepo --from-repofile=<url>   (no leading dashes on addrepo)
#      "--add-repo" is dnf4 syntax and fails on Fedora 41+.
# FIX: HashiCorp's repo uses $releasever which may not resolve on Fedora 43
#      since HashiCorp hasn't published fc43 packages yet — pin it to 42.
echo "→ Installing Terraform..."
if ! command -v terraform &>/dev/null; then
  sudo dnf config-manager addrepo \
    --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
  sudo sed -i 's/\$releasever/42/g' /etc/yum.repos.d/hashicorp.repo
  sudo dnf install -y terraform
fi

# ─── Ansible ──────────────────────────────────────────────────────────────────
# Installed via pipx so it has its own isolated Python environment
echo "→ Installing Ansible..."
pipx install ansible-core || pipx upgrade ansible-core

# ─── Stow dotfiles ────────────────────────────────────────────────────────────
# FIX: Added per-package directory guard. Without it, stow errors out with a
#      hard failure if any of the listed package dirs don't exist yet, which
#      aborts the whole script on a first-time run.
echo "→ Symlinking dotfiles..."
cd ~/.dotfiles
for pkg in bash git zed; do
  if [ -d "$pkg" ]; then
    stow "$pkg"
  else
    echo "  ⚠ Skipping stow $pkg — directory ~/.dotfiles/$pkg not found"
  fi
done

echo ""
echo "✓ Done!"
echo ""
echo "  Next steps:"
echo "  1. Run: source ~/.bashrc"
echo "  2. Log out and back in so the docker group takes effect"
echo "  3. Verify Docker works: docker run hello-world"
