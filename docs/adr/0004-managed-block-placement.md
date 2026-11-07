---
id: ADR-0004
title: Managed blocks go first in last-wins files so user settings take precedence
status: Accepted
date: 2026-11-07
refines: ADR-0002
---

## Context

ADR-0002 adopts each top-level dotfile with a single managed block and promises that the user owns the file. Every block was *appended*. In `~/.gitconfig` and `~/.tmux.conf`, the last value read wins, so an appended block quietly overrode the user's own settings. On a real machine this turned the user's `core.editor = vim` into the template's `nvim`, swapped in the template's `excludesFile`, and replaced a tmux `split-window -c "#{pane_current_path}"` binding. The user's lines were still there; they just stopped having any effect, which is worse than an error.

## Options Considered

### Option A: Keep appending; document that Shellcraft's values win

- **Pro:** no code change.
- **Con:** contradicts ADR-0002's ownership promise. Users must read the managed file to learn why their setting does nothing.

### Option B: Put the block first in last-wins files (chosen)

- **Pro:** Shellcraft supplies defaults and the user's lines override them, which is what "the user owns the file" means.
- **Con:** placement now depends on the file's semantics, not one rule.

### Option C: Put the block first everywhere, `.zshrc` included

- **Con:** `.zshrc` is a script, not last-wins config. A managed block that runs first would load Oh My Zsh before a user's own Oh My Zsh setup, which then loads it again (the bug fixed alongside this ADR). Appending, plus the managed zshrc's "already loaded" guard, is the safe order there.

## Decision

**Option B.**

| File | Placement | Why |
|---|---|---|
| `~/.gitconfig` | top | last value wins |
| `~/.tmux.conf` | top | later commands override earlier ones |
| `~/.zshrc` | bottom | script; managed zshrc skips anything the user already loaded |
| `~/.zprofile` | bottom | script; only adds Homebrew shellenv |

A block that already exists is **never moved**. Placement applies only when Shellcraft first adopts a file, so existing installs keep their current behavior until the user moves the block or deletes it and re-runs apply.

## Consequences

### Positive

- User settings in gitconfig/tmux always win over Shellcraft defaults on new adoptions.
- No surprise edits to files Shellcraft already manages.

### Negative

- Installs adopted before this ADR still have the block at the bottom. A future `doctor` check could flag that and offer to move it (with a plan preview, per ADR-0001).

### Risks

- New dotfiles adopted later must choose a placement explicitly by these semantics. `add_block_if_missing` defaults to `bottom`.
