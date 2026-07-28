# dotfiles

Fedora workstation setup. `install.sh` takes a fresh install to a fully
configured desktop and dev machine.

---

## Fresh machine

```bash
sudo dnf install -y git
git clone https://github.com/ajwadtahmid/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
sudo bash install.sh
```

Two prompts up front, then it runs unattended. Safe to re-run any time — every
step checks before acting, so a re-run only fills in what's missing or failed.

```bash
sudo bash install.sh --help                              # what it does
sudo bash install.sh --mode devcontainer --shell zsh     # skip the prompts
sudo bash install.sh --mode baremetal --with-devcontainer
```

### Prompt 1 — install mode

| Mode | What it does |
|------|--------------|
| **Devcontainer** *(default)* | Everything except the optional toolchain. Languages and DBs stay in containers. |
| **Baremetal** | Also installs Go, Rust, Java/Gradle, Expo, and local PostgreSQL + MariaDB on the host. |

Both install Python, Node, and Flutter on the host, so work is still possible
if a container won't come up.

### Prompt 2 — shell

| Choice | What you get |
|--------|--------------|
| **bash** *(default)* | oh-my-posh, `agnosterplus` theme |
| **zsh** | oh-my-zsh + powerlevel10k, autosuggestions, syntax highlighting, set as login shell |

Both get JetBrains Mono Nerd Font (also set as Konsole's default), plus
`zoxide`, `fzf`, `atuin`, and the `ll` / `gs` / `gp` / `dc` aliases.

**Choosing zsh requires a full log out and back in.** A new tab in the current
session still starts bash. Check with `getent passwd $USER` — last field should
end in `/zsh`.

---

## After it finishes

- **Log out and back in** — needed for the docker group, and for zsh
- SSH key: `ssh-keygen -t ed25519`, add `~/.ssh/id_ed25519.pub` to GitHub
- [JetBrains Toolbox](https://www.jetbrains.com/toolbox/) and
  [Android Studio](https://developer.android.com/studio) are manual installs
- Anything that failed is listed at the end — re-run to retry
- If a Zed `settings.json` already existed it wasn't touched; the recommended
  config is printed at the end to copy from

---

## Dev containers

### Start a project

```bash
cd ~/projects/my-app
devinit                    # copies the .devcontainer/ template in
```

Then in **Zed**: open the project → command palette (`Ctrl+Shift+P`) →
**`dev: reopen in container`**. First run pulls the image and starts the
database services, so give it a few minutes.

In VS Code it's **Reopen in Container**.

### Pull / refresh the image

The container uses `ghcr.io/ajwadtahmid/devenv:latest`, rebuilt weekly by
GitHub Actions. Your editor pulls it automatically on first open, but to grab
the newest build by hand:

```bash
docker pull ghcr.io/ajwadtahmid/devenv:latest
```

If the package is private, log in first:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u ajwadtahmid --password-stdin
```

To pin a project to a known-good build instead of tracking `latest`, set a
dated tag before opening it:

```bash
export DEVENV_TAG=2026.07.27
```

### What's inside

Python, Node, Rust, Go, Java, Kotlin, Scala, Swift, Flutter, Android SDK,
Terraform, Claude Code — plus PostgreSQL, MySQL, Redis, and MongoDB as separate
services, reachable through these env vars:

```
POSTGRES_URL   postgresql://dev:dev@postgres:5432/devdb
MYSQL_URL      mysql://dev:dev@mysql:3306/devdb
REDIS_URL      redis://default:dev@redis:6379
MONGO_URL      mongodb://dev:dev@mongo:27017/devdb?authSource=admin
```

Credentials are `dev` / `dev` — local development only.

Host ports are remapped to avoid clashing with baremetal services: Postgres on
`5433`, MySQL on `3307`. Inside the container use the service names and normal
ports, as above.

### Useful commands

Run these from the project's `.devcontainer/` directory:

```bash
docker compose ps                  # what's running and healthy
docker compose logs -f postgres    # tail a service
docker compose down                # stop everything
docker compose down -v             # stop AND wipe database volumes
docker compose pull                # refresh images
```

---

## Changing the dev container

Edit the template — it's the single source of truth:

```
devcontainer-template/.devcontainer/
├── devcontainer.json      extensions, forwarded ports, features
└── docker-compose.yml     the dev container + database services
```

Then rebuild the container in Zed/VS Code for the change to take effect.

**Note:** `devinit` copies the template at scaffold time. Projects created
earlier keep their own copy — update those by hand or delete their
`.devcontainer/` and re-run `devinit`.

Also, `install.sh` deploys this template to
`~/.dotfiles/devcontainer-template/`. If editing the repo somewhere else,
re-run the installer (or copy the folder over) so `devinit` picks it up.

### Changing what's *in* the image

Edit `docker/Dockerfile`, then push — the workflow rebuilds and publishes on
any change under `docker/`.

```bash
docker build -t devenv-test docker/    # test locally first
```

The image is amd64-only. Tags published: `latest`, a dated `YYYY.MM.DD`, and
the commit SHA.

---

## Layout

```
install.sh                    the setup script
bin/devinit                   scaffolds .devcontainer/ into a project
devcontainer-template/        dev container template (source of truth)
docker/                       the devenv image published to GHCR
.github/workflows/devenv.yml  builds and pushes that image
install-arch-debian.sh        Debian/Arch port of install.sh
archive/                      older versions
```

Shell and Git config are applied by `install.sh` directly — no dotfiles to
symlink.
