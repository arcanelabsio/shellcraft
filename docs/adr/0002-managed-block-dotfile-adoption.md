---
id: ADR-0002
title: Dotfiles are adopted via a single include/source block; never overwritten wholesale
status: Accepted
date: 2026-04-17
---

## Context

Most dotfile bootstrap tools take one of two stances: (a) symlink the entire `~/.zshrc` / `~/.gitconfig` / `~/.tmux.conf` to a repo-owned file (dotfiles-as-repo), or (b) regenerate the file from a template on every run. Both make a bet about who owns the file. Shellcraft wants the user to own their top-level dotfiles and Shellcraft to own only a narrow, predictable layer — because the target user is a developer who already has their own `~/.zshrc` tweaks they don't want stomped.

## Options Considered

### Option A: Symlink top-level dotfiles to repo-owned files
- **Pro:** canonical dotfiles-as-repo pattern; one source of truth.
- **Con:** the user loses their existing `~/.zshrc`. Backup-and-restore mitigations are error-prone.
- **Con:** user-specific customizations (work machine vs personal, per-host secrets) get awkward to layer.

### Option B: Regenerate dotfiles from templates each run
- **Pro:** deterministic; idempotent.
- **Con:** same destructive posture as symlinks — user edits disappear on the next run.

### Option C: Managed `~/.config/shellcraft/` layout + single include block in each top-level dotfile (chosen)
Shellcraft owns `~/.config/shellcraft/{zprofile.sh, zshrc.zsh, gitconfig, tmux.conf, gitignore_global, state.env}`. Top-level dotfiles get a single include/source block inserted pointing at the managed files:

- `~/.zprofile` sources `~/.config/shellcraft/zprofile.sh`
- `~/.zshrc` sources `~/.config/shellcraft/zshrc.zsh`
- `~/.gitconfig` includes `~/.config/shellcraft/gitconfig`
- `~/.tmux.conf` sources `~/.config/shellcraft/tmux.conf`

Everything else in the user's dotfile is left alone. Shellcraft detects the block by a marker and replaces only what's inside it on subsequent runs. The user also gets `~/.config/shellcraft/local.zsh` as an explicitly user-owned layer that `zshrc.zsh` sources but never writes to.

- **Pro:** the user keeps their `~/.zshrc`; Shellcraft's edit is one block they can grep for.
- **Pro:** user-owned per-machine customization lives in `local.zsh` with no tooling coupling.
- **Pro:** uninstall is tractable — remove the include block and the managed directory.
- **Con:** include-block splicing is more complex than overwriting; corner cases (missing file, existing block with different content, user edited the block) need to be handled in `lib/config_adoption.sh`.

## Decision

**Option C.** Shellcraft writes to `~/.config/shellcraft/` and adopts top-level dotfiles via a single include/source block. The block is the only part Shellcraft mutates; everything else in the dotfile is the user's and must survive every run. Git identity is never auto-filled; if `user.name` / `user.email` are missing from the user's actual git config, Shellcraft reports it rather than inventing a placeholder.

Any new dotfile Shellcraft touches must follow the same pattern.

## Consequences

### Positive
- Users trust the tool on existing machines. The managed block is small and reviewable.
- `local.zsh` gives users a clean escape hatch for per-machine customization without forking or overriding.
- Uninstall has a known shape.

### Negative
- The include-block splicer in `lib/config_adoption.sh` is more code than a write-full-file approach.
- Users can edit inside the managed block and lose changes on next run. The marker text itself warns against this; the invariant is documented in `AGENTS.md`.

### Risks
- **Marker-format drift.** Changing the marker syntax would orphan existing installs. The current marker format is a long-term stable contract.
- **Exotic shell setups.** Some users have unusual `~/.zshrc` structures (oh-my-zsh, prezto, custom loaders). The include block must be additive and order-tolerant. `tests/*.bats` covers the common cases; edge cases land as bug reports.
