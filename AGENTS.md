# AGENTS.md — Shellcraft

> Authoritative guide for AI coding assistants (Claude Code, Codex, etc.) working in this repo. `CLAUDE.md` imports this file via `@AGENTS.md`; edit here, not there.

## Purpose

Shellcraft bootstraps and maintains a macOS developer machine. The repo's job is to keep that bootstrap **safe, previewable, and non-destructive**: profile-based Homebrew package selection, managed-block dotfile adoption, and a maintainer toolchain that self-checks. See `DESIGN.md` for the pattern-vs-implementation split.

## Key Rules

- **Preview before apply.** `--plan` is the default mode of `setup-my-mac.sh`. Any new capability must have a dry-run / plan path before an apply path. Never introduce an apply-only command.
- **Managed-block dotfiles, never wholesale rewrites.** Shellcraft adopts `~/.zprofile`, `~/.zshrc`, `~/.gitconfig`, `~/.tmux.conf` by appending a single include/source block. User content outside the managed block must survive every run. The adoption logic lives in `lib/config_adoption.sh` — do not bypass it.
- **Opt-in for anything with side effects on the user's identity or environment.** Login shell change (`SET_DEFAULT_SHELL`), font install (`WITH_FONTS`), GUI-assisted Xcode CLT install (`ALLOW_GUI_INSTALLS`) all default to off.
- **Never auto-fill git identity.** If `user.name` / `user.email` are missing, report it. Don't invent a placeholder.
- **Profiles are additive.** A `PROFILE=core,backend` install must not uninstall anything from `core`. Removal is explicit and user-driven, not inferred.
- **Homebrew is the only package manager.** Out of scope: Linux, non-Homebrew managers, paid tools, sign-in-required defaults, GUI app management beyond optional fonts.
- **Conventional Commits.** `feat|fix|chore|docs|refactor|test|ci(<scope>): <subject>`. No co-author trailers.

## Invariants that must not be broken

1. **Dotfiles are adopted, not overwritten.** If a change would replace a user's top-level dotfile wholesale, it's wrong. The managed block is the only legitimate edit surface.
2. **Every profile lists installable Brewfile entries only.** A profile that can't be resolved by `brew bundle --file=...` is a bug.
3. **`make plan PROFILE=...` is idempotent and read-only.** It must never write to the filesystem outside of `/tmp`.
4. **`tests/*.bats` runs in a temp HOME.** Tests must never touch the operator's real dotfiles.
5. **Maintainer workflow stays separate.** `task lint/fmt-check/test/smoke-*` are for maintainers. First-run users never need `task`.

## Where to find the contract

- **Pattern (what this repo is trying to be):** `DESIGN.md`
- **User-facing entry points:** `Makefile`, `setup-my-mac.sh`
- **Planner and adoption core:** `lib/planner.sh`, `lib/config_adoption.sh`, `lib/verifier.sh`, `lib/profile_metadata.sh`
- **Profile definitions:** `profiles/*.Brewfile`
- **Managed templates:** `templates/*`
- **Smoke tests:** `tests/*.bats` (run against a temp HOME)
- **Maintainer tasks:** `Taskfile.yml`, `.pre-commit-config.yaml`
- **ADRs:** `docs/adr/` — read before proposing structural changes

## Commands an agent will typically run

```bash
make plan PROFILE=core                # preview
make install PROFILE=core             # apply
make doctor PROFILE=core              # verify
task lint && task fmt-check && task test
task smoke-fresh && task smoke-existing
```
