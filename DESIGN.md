# Shellcraft — Design

This document describes the **pattern** Shellcraft implements, separated from the specific **macOS + Homebrew** implementation. The pattern is the reusable idea; the implementation is one host it lives in.

A Linux fork, a Windows fork, or an Alpine-in-a-container fork should be able to start here and re-derive the implementation without reverse-engineering `setup-my-mac.sh`.

---

## The pattern

Shellcraft solves this problem: **a developer wants to stand up a fresh machine quickly, or re-provision an existing machine without breaking what they have, using a short, opinionated set of tools that they actually use.**

Four invariants make this pattern safe:

### 1. Profile-based package selection

Package selection is driven by named **profiles** (`core`, `backend`, `ai`, `containers`, `local-ai`, `maintainer`, ...), not by a monolithic "install everything." Profiles are additive — installing `backend` on top of `core` extends; it never removes.

Why it matters: profiles let the same tool serve a minimal terminal machine, a Kubernetes-heavy workflow, and a maintainer's own toolchain. Without profiles the tool is either too lean (missing what people need) or too bloated (installing things nobody asked for).

### 2. Preview-first execution

Every capability has a **plan** path that shows what would change and an **apply** path that actually changes it. Plan is the default. Apply requires an explicit flag. Running the tool "just to see" produces a preview, never a side effect.

Why it matters: developers habitually paste commands they haven't read. A preview-by-default tool is safe to document in terse form (`bash <(curl ...)`) because the worst outcome is a wall of "here's what I'd do."

See [ADR-0001](docs/adr/0001-preview-first-default.md).

### 3. Managed-block configuration adoption

Top-level dotfiles are **not overwritten**. The tool owns a subdirectory (e.g., `~/.config/shellcraft/`) that holds its managed configs. It inserts exactly one **include/source block** into each top-level dotfile pointing at that subdirectory. Everything else in the dotfile is the user's and must survive every run.

The managed block is detected by a marker so subsequent runs replace only what's inside it. Users who want a per-machine escape hatch get an explicitly user-owned file (in Shellcraft's case, `~/.config/shellcraft/local.zsh`) that the managed files source but never write to.

Why it matters: a developer with a curated `~/.zshrc` will not run a tool that stomps it. Adoption-with-a-marker is the only approach that is safe on existing machines without asking the user to stage an elaborate backup.

See [ADR-0002](docs/adr/0002-managed-block-dotfile-adoption.md).

### 4. Opt-in for identity and environment-altering side effects

Anything that changes the user's identity (git `user.name` / `user.email`, login shell) or installs something with ongoing behavioral consequences (fonts, GUI-assisted installs) must be explicitly opted in. Missing values are **reported**, never auto-filled with placeholders.

Why it matters: the difference between "helpful" and "presumptuous" is whether the tool guessed about who the user is. Guessing once gets forgiven; guessing systematically is why people distrust bootstrap scripts.

---

## Anatomy of a Shellcraft-like tool

Any implementation of this pattern has five parts. In this repo they map to the files in parentheses.

1. **A planner** that reads the current machine state, compares it to the desired profile state, and emits a structured description of the delta. (`lib/planner.sh`)
2. **Profile definitions** that are declarative and grep-friendly. Ideally a format a user can read and edit without learning the tool. (`profiles/*.Brewfile`)
3. **A config-adoption module** that handles the managed-block splicing for each dotfile, including the "already has a block with stale content" case and the "file doesn't exist yet" case. (`lib/config_adoption.sh`)
4. **Managed templates** under the tool's own subdirectory. Users are not expected to edit these; they are expected to override from `local.zsh`. (`templates/*`)
5. **A verifier / doctor** that runs after apply to confirm the machine matches the plan, and can surface drift if run on a machine that has evolved away from its Shellcraft-managed state. (`lib/verifier.sh`, `make doctor`)

These are the load-bearing five. Everything else — CLI surface (`Makefile`, `setup-my-mac.sh`), tests (`tests/*.bats`), maintainer tooling (`Taskfile.yml`), exercises — is scaffolding around them.

---

## The macOS + Homebrew implementation

This repo instantiates the pattern as follows:

| Pattern concept | This repo's implementation |
|---|---|
| Package manager | Homebrew (`brew`) |
| Profile format | Brewfile (consumed via `brew bundle --file=...`) |
| Planner | `lib/planner.sh` — parses Brewfiles, queries installed state, emits delta |
| Config adoption | `lib/config_adoption.sh` — marker-based splicing |
| Managed subdirectory | `~/.config/shellcraft/` |
| User escape hatch | `~/.config/shellcraft/local.zsh` |
| Top-level targets | `~/.zprofile`, `~/.zshrc`, `~/.gitconfig`, `~/.tmux.conf` |
| Verifier | `lib/verifier.sh`, invoked by `make doctor` / `--doctor` |
| Remote bootstrap | `setup-my-mac.sh` served via raw GitHub URL |
| Test harness | `tests/*.bats` running in a temp HOME |

macOS-specific facts that the implementation leans on:

- Zsh is the default login shell post-Catalina; `~/.zprofile` and `~/.zshrc` are the right adoption targets.
- Homebrew installs to `/opt/homebrew` on Apple Silicon and `/usr/local` on Intel — the `zprofile.sh` template handles both.
- Xcode Command Line Tools are the minimum dependency to install `make` and Homebrew; the remote bootstrap path handles the "fresh machine with nothing" case.

Out of scope for this implementation (but the pattern accommodates them in a fork):

- Linux (apt/dnf/pacman profiles, different dotfile conventions)
- Non-Homebrew macOS (MacPorts, Nix on macOS)
- Paid tools, sign-in-required defaults, GUI app management beyond optional fonts

See [ADR-0003](docs/adr/0003-macos-homebrew-only-scope.md).

---

## Porting the pattern to another environment

A port starts by answering, in order:

1. **What is the package manager?** Whatever it is, that's the moral equivalent of `brew` and its declarative file format (Brewfile equivalent) is the moral equivalent of profiles.
2. **What dotfiles need adopting?** List them. For each, define the marker syntax (comment style that works in that file type) and pick the adoption target (source / include / read).
3. **Where does the managed subdirectory live?** Pick a path under the user's config home (`$XDG_CONFIG_HOME` is a safe default on Linux).
4. **What's the minimum dependency for the package manager to exist?** That's what the remote bootstrap script has to install first.
5. **What identity / environment changes are opt-in?** Login shell, git identity, fonts, GUI-assisted installs — list them as explicit flags.

If you've answered the five, the rest of the implementation is a translation exercise. The invariants (profile-based, preview-first, managed-block, opt-in) port verbatim.
