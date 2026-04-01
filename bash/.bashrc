# ─── Local binaries ───────────────────────────────────────────────────────────
# Ensure user-level bin directories are on PATH first, so local installs
# (pipx tools, custom scripts, etc.) take precedence over system packages.
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# ─── pyenv ────────────────────────────────────────────────────────────────────
# pyenv intercepts python/pip calls and routes them to the correct version.
# PYENV_ROOT must be set before the shims directory is added to PATH.
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
# The eval adds pyenv shims to PATH and sets up the shell function used
# by pyenv to switch versions when you enter a directory with .python-version

# ─── fnm (Node.js) ────────────────────────────────────────────────────────────
# fnm works similarly to pyenv — it injects shims and auto-switches versions.
# --use-on-cd means fnm checks for .nvmrc / .node-version when you cd
eval "$(fnm env --use-on-cd)"

# ─── SDKMAN (Java, Kotlin, Scala, Maven, Gradle) ──────────────────────────────
# SDKMAN sources itself as a shell function rather than adding shims.
# The double-bracket test checks the file exists before sourcing it,
# which prevents errors if SDKMAN is not yet installed.
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# ─── Rust ─────────────────────────────────────────────────────────────────────
# Cargo's env file sets PATH to include ~/.cargo/bin where rustc, cargo,
# and any binaries installed with `cargo install` live.
source "$HOME/.cargo/env"

# ─── Go ───────────────────────────────────────────────────────────────────────
# /usr/local/go/bin contains the go binary itself.
# $GOPATH/bin (defaults to ~/go/bin) is where `go install` puts binaries.
export GOPATH="$HOME/go"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"

# ─── Flutter / Dart ───────────────────────────────────────────────────────────
# The Flutter SDK is cloned to ~/flutter — add its bin to PATH so that
# both `flutter` and `dart` commands are available.
export PATH="$PATH:$HOME/flutter/bin"

# ─── swiftenv ─────────────────────────────────────────────────────────────────
export SWIFTENV_ROOT="$HOME/.swiftenv"
export PATH="$SWIFTENV_ROOT/bin:$PATH"
eval "$(swiftenv init -)"

# ─── Aliases ──────────────────────────────────────────────────────────────────
alias ll='ls -lah --color=auto'   # Long listing with human-readable sizes
alias gs='git status'
alias gp='git pull'
alias dc='docker compose'         # Shorthand for docker compose commands

# Container lifecycle helpers (used with JetBrains Gateway — see Part 5)
alias devup='docker run -d --name devenv \
  -v "$(pwd)":/workspace \
  -v "$HOME/.ssh":/home/dev/.ssh:ro \
  -v "$HOME/.gitconfig":/home/dev/.gitconfig:ro \
  -w /workspace \
  ghcr.io/YOUR_GITHUB_USERNAME/devenv:latest sleep infinity'
alias devdown='docker stop devenv && docker rm devenv'
alias devsh='docker exec -it devenv bash'
