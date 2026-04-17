---
id: ADR-0001
title: `--plan` (preview) is the default mode; apply requires an explicit flag
status: Accepted
date: 2026-04-17
---

## Context

Shellcraft modifies a developer's machine: installs Homebrew formulae, edits dotfiles, adopts a managed config layout, and can change the login shell. Users running it for the first time don't always read the docs before executing. The design question is: what happens if someone runs `./setup-my-mac.sh` with no arguments?

Two defensible defaults:

- **Apply by default.** One command gets the machine set up; fastest time-to-useful.
- **Preview by default.** One command shows what would happen; the user has to opt in to the write.

## Options Considered

### Option A: Apply by default
- **Pro:** faster first-run success path.
- **Con:** destructive and non-obvious if the user didn't mean to run it — installed formulae, adopted dotfiles, edited `~/.zshrc`.
- **Con:** removing later is a lot more work than having not applied in the first place.

### Option B: Preview by default (chosen)
Running `./setup-my-mac.sh` with no args prints a plan of everything it would change — Brewfile installs, managed file writes, dotfile inclusion edits — without touching the filesystem. Apply requires `--apply`. Similarly, `make` alone prints help; `make plan PROFILE=core` previews; `make install PROFILE=core` applies.
- **Pro:** no surprise destructive actions. A user who runs it "just to see" sees, not reshapes.
- **Pro:** matches the safety posture of industry tools the target audience already uses (`terraform plan`/`apply`, `brew bundle check`/`install`).
- **Pro:** makes the remote bootstrap path (`bash <(curl ...)`) safe to copy-paste in docs without a foot-gun.
- **Con:** two commands instead of one to actually install.
- **Con:** some users will run plan and never follow up; that is fine.

## Decision

**Option B.** `--plan` is the default mode; `--apply` is required to make changes. The `Makefile` enforces the same stance (`make plan` vs `make install`). The remote bootstrap script (`setup-my-mac.sh`) preserves this: with no args it previews, and `--apply --profile <name>` is the explicit install path.

Any new capability added to Shellcraft must have a plan path before it has an apply path. A feature that only applies is a bug.

## Consequences

### Positive
- First-run is always safe. Copy-paste from docs doesn't reshape a machine.
- The planner is the heart of the tool; because it's on the default path, it stays good.
- Easy to debug issues — "what would Shellcraft do?" always has an answer without running anything.

### Negative
- Users must type two commands to install (plan then install). Mitigated by clear docs and the `make install` shortcut.
- Maintenance requires keeping the planner honest; a drift between "what plan says" and "what install does" would be a serious bug.

### Risks
- **Planner drift.** If planner and applier diverge, the default-safe posture becomes a lie. Mitigated by smoke tests (`task smoke-fresh`, `task smoke-existing`) that assert plan→apply produces the state the planner predicted.
