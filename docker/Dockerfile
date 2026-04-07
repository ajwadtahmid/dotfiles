# syntax=docker/dockerfile:1
FROM ubuntu:24.04

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
# FIX: "AARG" typo corrected to "ARG"
# FIX: Ubuntu 24.04 pre-creates a group+user called "ubuntu" with UID/GID 1000.
#      groupadd/useradd fail with exit code 4 if the GID/UID already exists.
#      We rename the existing ubuntu user/group to "dev" instead.
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupmod --new-name $USERNAME $(getent group $USER_GID | cut -d: -f1) \
    && usermod --login $USERNAME --move-home --home /home/$USERNAME \
       $(getent passwd $USER_UID | cut -d: -f1) \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME

# FIX: USER instruction was missing entirely. Without it, all subsequent RUN
#      commands execute as root, $HOME resolves to /root, and every tool gets
#      installed into the wrong location — breaking all PATH references.
USER $USERNAME
WORKDIR /home/$USERNAME
ENV HOME=/home/$USERNAME

# ─── pyenv + Python 3.12 ──────────────────────────────────────────────────────
# FIX: 3.12.0 → 3.12.13. Python 3.12.0 fails to build on Ubuntu 24.04 due to
#      a Tcl_Size type mismatch introduced in Tcl 8.7/9.0.
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
# FIX: Added --shell bash to "fnm env". Non-interactive RUN layers require it
#      or fnm won't set up the environment and subsequent commands fail.
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
# FIX: 1.23.0 → 1.26.1 (1.23.x is EOL as of April 2026).
# FIX: Removed "sudo tar" — at this point we are the dev user with write access
#      via sudo, but the cleaner approach is to just use sudo explicitly in the
#      full command rather than piping into it.
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
# FIX: Replaced swiftenv entirely. swiftenv pulls CentOS 7 / old Ubuntu
#      prebuilt binaries that are incompatible with Ubuntu 24.04's glibc.
#      Use the official Swift 6.3 Ubuntu 24.04 tarball from swift.org instead.
#      Swift 6.3 is the latest stable release as of April 2026.
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
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
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
# FIX: COPY comes after USER so the file lands in the correct home directory.
#      The --chown flag still works correctly with the named user.
COPY --chown=$USERNAME:$USERNAME bashrc $HOME/.bashrc

CMD ["/bin/bash"]
