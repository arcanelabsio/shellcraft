# Shellcraft

> Built at **[Arcane Labs](https://github.com/arcanelabsio)** — local-first, BYO-AI tools. Sibling projects: [Forge](https://github.com/arcanelabsio/forge), [Longeviti](https://github.com/arcanelabsio/longeviti-framework), [Vael](https://github.com/arcanelabsio/vael).

Shellcraft bootstraps and maintains a macOS developer machine with:

- profile-based package selection
- preview-first execution
- Shellcraft-managed include files instead of destructive dotfile rewrites
- a maintainer toolchain for keeping this repo healthy

The **pattern** Shellcraft implements (profile-based bootstrap with preview-first, managed-block adoption) is described separately from this repo's macOS + Homebrew implementation in [DESIGN.md](DESIGN.md) — read it first if you want to port the idea to another environment.

## Quick Start

Shellcraft now has two usage lanes:

- `make` for normal local usage after clone or download
- `setup-my-mac.sh` for the one-line remote bootstrap flow

### Local Usage With `make`

Start with a safe preview:

```bash
make plan PROFILE=core
```

Apply the default profile after reviewing the plan:

```bash
make install PROFILE=core
```

Common follow-up commands:

```bash
make doctor PROFILE=core
make fix PROFILE=core
make install PROFILE=core,backend,ai
make install PROFILE=containers WITH_FONTS=1 SET_DEFAULT_SHELL=1
```

### If `make` Is Missing

On macOS, `make` comes from Xcode Command Line Tools. If your machine does not
have `make` yet, bootstrap Shellcraft once with the remote installer:

```bash
URL="https://raw.githubusercontent.com/arcanelabsio/shellcraft/main/setup-my-mac.sh"
bash <(curl -fsSL "$URL") --apply --profile core
```

That installs the shellcraft `core` profile and gives the machine Xcode Command
Line Tools, which includes `make`. After that, reopen your shell or run:

```bash
exec zsh -l
make plan PROFILE=core
```

### Single-Command Remote Install

Preview-only remote run:

```bash
URL="https://raw.githubusercontent.com/arcanelabsio/shellcraft/main/setup-my-mac.sh"
bash <(curl -fsSL "$URL")
```

Install immediately with the default `core` profile:

```bash
URL="https://raw.githubusercontent.com/arcanelabsio/shellcraft/main/setup-my-mac.sh"
bash <(curl -fsSL "$URL") --apply --profile core
```

This remote path bypasses the `Makefile` and runs the Shellcraft engine
directly.

## User Interface

`make` is the primary local interface for users:

```bash
make
make help
make plan PROFILE=core
make install PROFILE=core
make doctor PROFILE=core
make fix PROFILE=core
```

Supported variables:

- `PROFILE`
  Comma-separated profiles, for example `PROFILE=core,backend`
- `WITH_FONTS`
  `0` or `1`
- `SET_DEFAULT_SHELL`
  `0` or `1`
- `ALLOW_GUI_INSTALLS`
  `0` or `1`

Notes:

- `make` with no target prints help
- `PROFILE` defaults to `core`
- `PROFILE` must not be empty
- profile lists are comma-separated without spaces

### Direct Engine Usage

`./setup-my-mac.sh` remains available for advanced or direct usage:

```bash
./setup-my-mac.sh --plan --profile core
./setup-my-mac.sh --apply --profile core --profile maintainer
./setup-my-mac.sh --doctor --profile core
./setup-my-mac.sh --doctor --fix --profile core
```

## Profiles

- `core`: daily terminal baseline
  Key tools: `git`, `tmux`, `fzf`, `ripgrep`, `jq`, `yq`, `gh`, `neovim`
- `backend`: API and Kubernetes workflow
  Key tools: `mise`, `direnv`, `xh`, `grpcurl`, `kubectl`, `helm`, `k9s`,
  `kubectx`
- `ai`: lightweight AI and Python workflow
  Key tools: `uv`
- `maintainer`: keep Shellcraft itself healthy
  Key tools: `shellcheck`, `shfmt`, `bats-core`, `pre-commit`, `go-task`,
  `markdownlint-cli`, `actionlint`, `yamllint`, `hadolint`
- `containers`: local container runtime
  Key tools: `colima`, `docker`, `docker-compose`
- `local-ai`: local model runtime
  Key tools: `ollama`

`--profile all` expands to every profile above.

## Safety Model

Shellcraft is intentionally conservative:

- `--plan` is the default mode
- top-level dotfiles are not overwritten wholesale
- missing Git identity is reported, never auto-filled with placeholders
- login shell changes are opt-in
- font installation is opt-in
- GUI-assisted Xcode Command Line Tools installation is opt-in

## Managed Config Layout

Shellcraft writes managed files under:

```bash
~/.config/shellcraft/
```

Managed files:

- `zprofile.sh`
- `zshrc.zsh`
- `gitconfig`
- `tmux.conf`
- `gitignore_global`
- `state.env`

User-owned file:

- `local.zsh`

Top-level files are adopted via a single include/source block:

- `~/.zprofile` sources `~/.config/shellcraft/zprofile.sh`
- `~/.zshrc` sources `~/.config/shellcraft/zshrc.zsh`
- `~/.gitconfig` includes `~/.config/shellcraft/gitconfig`
- `~/.tmux.conf` sources `~/.config/shellcraft/tmux.conf`

## Maintainer Workflow

`task` is for maintainers and repository checks, not first-run user setup.

Install the `maintainer` profile on a Shellcraft machine, then use:

```bash
task lint
task fmt-check
task test
task smoke-fresh
task smoke-existing
task doctor
```

Pre-commit hooks are defined in `.pre-commit-config.yaml`.
At commit time, pre-commit runs `task lint` as a repo-wide lint pass and
reports the full repository state.

## Repository Layout

```text
Makefile                    User-facing local wrapper
setup-my-mac.sh             Shellcraft engine
profiles/*.Brewfile         Profile package definitions
lib/*.sh                    Planner, config adoption, verification helpers
templates/*                 Managed config templates
tests/*.bats                Temp-HOME smoke tests
Taskfile.yml                Maintainer tasks
.pre-commit-config.yaml     Maintainer hooks
exercises/*.md              Learning material
```

Exercise guides currently available:

- `exercises/terminal-exercises.md`: `core` profile exercises
- `exercises/maintainer-exercises.md`: `maintainer` profile exercises
- `exercises/k8s-exercises.md`: Kubernetes-focused `yq` and `jq` follow-up

## Scope

In scope:

- macOS
- Homebrew-managed tooling
- free CLI tools
- safe bootstrap and ongoing machine maintenance

Out of scope:

- paid tools
- sign-in-required defaults
- Linux support
- GUI app management other than optional fonts
- package managers other than Homebrew
