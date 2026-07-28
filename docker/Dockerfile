# syntax=docker/dockerfile:1
FROM ubuntu:26.04

LABEL org.opencontainers.image.source=https://github.com/ajwadtahmid/dotfiles
LABEL org.opencontainers.image.description="Universal dev environment"

ENV DEBIAN_FRONTEND=noninteractive

# ─── System packages ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core tools
    git curl wget sudo ca-certificates gnupg lsb-release \
    tar gzip unzip zip bash-completion procps \
    # C / C++ toolchain
    gcc g++ clang clang-format clang-tidy cmake make ninja-build \
    # Qt6 development headers
    qt6-base-dev qt6-declarative-dev qt6-tools-dev \
    # Lua
    lua5.4 liblua5.4-dev \
    # Python build dependencies for pyenv
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev libffi-dev liblzma-dev tk-dev \
    # Tauri desktop app dependencies
    libwebkit2gtk-4.1-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev \
    # Java 21 LTS
    openjdk-21-jdk \
    # Android Debug Bridge
    adb \
    # Useful CLI tools
    openssh-client less jq ripgrep fd-find \
    # Database clients
    postgresql-client default-mysql-client redis-tools sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# ─── Create a non-root user ───────────────────────────────────────────────────
# Ubuntu pre-creates a group+user called "ubuntu" with UID/GID 1000, and
# groupadd/useradd fail with exit code 4 when the GID/UID already exists — so
# rename that existing user/group to "dev" rather than creating a new one.
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupmod --new-name $USERNAME $(getent group $USER_GID | cut -d: -f1) \
    && usermod --login $USERNAME --move-home --home /home/$USERNAME \
       $(getent passwd $USER_UID | cut -d: -f1) \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME

# Everything below runs as the dev user. Without this, RUN layers execute as
# root, $HOME resolves to /root, and the tooling lands outside the PATHs set
# further down.
USER $USERNAME
WORKDIR /home/$USERNAME
ENV HOME=/home/$USERNAME

# ─── pyenv + Python 3.12 ──────────────────────────────────────────────────────
# Pinned to 3.12.13: 3.12.0 fails to build against Tcl 8.7/9.0 (Tcl_Size type
# mismatch), so don't lower this patch version.
RUN curl https://pyenv.run | bash
ENV PYENV_ROOT="$HOME/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PATH"
RUN eval "$(pyenv init -)" && \
    pyenv install 3.12.13 && \
    pyenv global 3.12.13 && \
    pip install --upgrade pip uv pipx && \
    python -m pipx install poetry

# ─── fnm + Node LTS ───────────────────────────────────────────────────────────
RUN curl -fsSL https://fnm.vercel.app/install | bash
ENV PATH="$HOME/.local/share/fnm:$PATH"
# --shell bash is required: fnm can't detect the shell in a non-interactive RUN
# layer, and without it the environment is never set up.
RUN eval "$(fnm env --shell bash)" && \
    fnm install --lts && fnm use lts-latest && \
    npm install -g typescript pnpm yarn

# ─── Claude Code ──────────────────────────────────────────────────────────────
RUN eval "$(fnm env --shell bash)" && \
    npm install -g @anthropic-ai/claude-code && \
    sudo ln -sf "$(npm config get prefix)/bin/claude" /usr/local/bin/claude

# ─── Bun ──────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="$HOME/.bun/bin:$PATH"

# ─── Rust ─────────────────────────────────────────────────────────────────────
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="$HOME/.cargo/bin:$PATH"
RUN rustup update stable && \
    cargo install cargo-watch cargo-edit

# ─── Go ───────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://go.dev/dl/go1.26.1.linux-amd64.tar.gz \
    -o /tmp/go.tar.gz && \
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz
ENV PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"

# ─── SDKMAN → Kotlin, Scala, Maven, Gradle ────────────────────────────────────
# Java is already installed via apt above, so we skip it here.
RUN curl -s "https://get.sdkman.io" | bash
ENV SDKMAN_DIR="$HOME/.sdkman"
RUN bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && \
    sdk install kotlin && \
    sdk install scala && \
    sdk install maven && \
    sdk install gradle"

# ─── Swift ────────────────────────────────────────────────────────────────────
# Installed from the official swift.org tarball rather than swiftenv, which
# ships CentOS 7 / old-Ubuntu binaries that are incompatible with this glibc.
RUN curl -fsSL \
    https://download.swift.org/swift-6.3-release/ubuntu2404/swift-6.3-RELEASE/swift-6.3-RELEASE-ubuntu24.04.tar.gz \
    -o /tmp/swift.tar.gz && \
    sudo tar -C /opt -xzf /tmp/swift.tar.gz && \
    rm /tmp/swift.tar.gz
ENV PATH="/opt/swift-6.3-RELEASE-ubuntu24.04/usr/bin:$PATH"

# ─── Flutter + Dart ───────────────────────────────────────────────────────────
RUN git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter
ENV PATH="$PATH:$HOME/flutter/bin"
RUN flutter precache --no-android --no-ios

# ─── Android SDK ──────────────────────────────────────────────────────────────
# The version number in the cmdline-tools URL (11076708) is tied to a specific
# release. Check https://developer.android.com/studio#command-line-tools-only
# for the latest zip if this URL stops working.
ENV ANDROID_HOME="$HOME/android-sdk"
RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
    curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    -o /tmp/cmdtools.zip && \
    unzip -q /tmp/cmdtools.zip -d $ANDROID_HOME/cmdline-tools && \
    mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest && \
    rm /tmp/cmdtools.zip
ENV PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# ─── Terraform ────────────────────────────────────────────────────────────────
# HashiCorp's apt repo lags new Ubuntu releases, so pin the suite to "noble"
# (24.04 LTS) instead of $(lsb_release -cs); its binaries run fine on newer bases.
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com noble main" | \
      sudo tee /etc/apt/sources.list.d/hashicorp.list && \
    sudo apt-get update && sudo apt-get install -y terraform && \
    sudo rm -rf /var/lib/apt/lists/*

# ─── mongosh ──────────────────────────────────────────────────────────────────
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
      sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg && \
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
      https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | \
      sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    sudo apt-get update && sudo apt-get install -y mongodb-mongosh && \
    sudo rm -rf /var/lib/apt/lists/*

# ─── Ansible ──────────────────────────────────────────────────────────────────
RUN eval "$(pyenv init -)" && python -m pipx install ansible-core

# ─── Shell setup ──────────────────────────────────────────────────────────────
# Must stay after USER so $HOME resolves to the dev user's home.
COPY --chown=$USERNAME:$USERNAME bashrc $HOME/.bashrc

CMD ["/bin/bash"]
