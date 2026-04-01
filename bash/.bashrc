# Prompt — show user, host, and working directory
PS1='\[\e[01;32m\]\u@\h\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\]\$ '

# ─── Local binaries ───────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# ─── pyenv ────────────────────────────────────────────────────────────────────
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# ─── fnm (Node.js) ────────────────────────────────────────────────────────────
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --use-on-cd --shell bash)"
fi

# ─── SDKMAN (Java, Kotlin, Scala, Maven, Gradle) ──────────────────────────────
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# ─── Rust ─────────────────────────────────────────────────────────────────────
source "$HOME/.cargo/env"

# ─── Go ───────────────────────────────────────────────────────────────────────
export GOPATH="$HOME/go"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"

# ─── Flutter / Dart ───────────────────────────────────────────────────────────
export PATH="$PATH:$HOME/flutter/bin"

# ─── Swift ────────────────────────────────────────────────────────────────────
# Installed via Fedora package (swift-lang) — no version manager needed
# swift binary is available system-wide via dnf, nothing to add to PATH

# ─── Chrome (Flatpak Brave) ───────────────────────────────────────────────────
export CHROME_EXECUTABLE=/var/lib/flatpak/exports/bin/com.brave.Browser

# ─── Aliases ──────────────────────────────────────────────────────────────────
alias ll='ls -lah --color=auto'
alias gs='git status'
alias gp='git pull'
alias dc='docker compose'

# Container lifecycle helpers
alias devup='docker run -d --name devenv \
  -v "$(pwd)":/workspace \
  -v "$HOME/.ssh":/home/dev/.ssh:ro \
  -v "$HOME/.gitconfig":/home/dev/.gitconfig:ro \
  -w /workspace \
  ghcr.io/ajwadtahmid/devenv:latest sleep infinity'
alias devdown='docker stop devenv && docker rm devenv'
alias devsh='docker exec -it devenv bash'
