---
id: ADR-0003
title: Scope is macOS + Homebrew; Linux, non-Homebrew managers, and paid tools are out
status: Accepted
date: 2026-04-17
---

## Context

Developer-machine bootstrap tools fall on a spectrum from "macOS dotfiles script" to "cross-platform infrastructure-as-code" (Ansible, Nix, chezmoi). The scope of Shellcraft is a deliberate choice — narrower scope means the tool stays simple, safe, and honest about what it does.

## Options Considered

### Option A: Cross-platform (macOS + Linux)
- **Pro:** broader audience.
- **Con:** Linux distros have wildly different package managers (apt, dnf, pacman, portage). Abstracting over them either means picking one (alienating the others) or building a meta-layer with inconsistent behavior per target.
- **Con:** shell conventions diverge (login shell, dotfile locations, default shells) and every "works on macOS" feature grows a Linux variant to maintain.

### Option B: Nix for reproducible everything
- **Pro:** the gold standard for reproducibility.
- **Con:** steep learning curve and the user's machine ends up owned by Nix, not by the user. Out of scope for a tool whose point is light-touch bootstrap.

### Option C: macOS + Homebrew only (chosen)
Scope is bounded:
- **In:** macOS, Homebrew-managed tooling, free CLI tools, safe bootstrap and ongoing machine maintenance.
- **Out:** Linux support, paid tools, sign-in-required defaults, GUI app management beyond optional fonts, package managers other than Homebrew.
- **Pro:** the tool stays understandable and auditable. Every profile is a Brewfile; every managed file is a template.
- **Pro:** the safety properties (preview-first, managed-block adoption, no auto-filled git identity) are well-defined because the target environment is well-defined.
- **Pro:** the README's "Scope" section doubles as a contract — users know what to expect.
- **Con:** developers on Linux can't use this directly. They can fork and swap `brew` for their package manager; the pattern (profile-based selection, preview-first, managed-block dotfiles) ports cleanly. `DESIGN.md` describes the pattern separately from the macOS/Homebrew implementation for exactly this reason.

## Decision

**Option C.** Shellcraft is macOS + Homebrew + free-CLI-tools. The scope is enforced by the absence of abstractions that would invite drift — there is no `brew` wrapper, no "if Linux" branch, no `apt` shim. `DESIGN.md` documents the pattern so a Linux fork is a comprehensible exercise rather than an archaeology project.

A proposal to extend scope (another OS, a paid tool, a non-Homebrew manager) must either (a) supersede this ADR with an explicit argument, or (b) be rejected. Scope creep on a tool whose job is safety is a long-term reliability bug.

## Consequences

### Positive
- Every Brewfile, template, and test is about one target — macOS + Homebrew.
- Onboarding for contributors is bounded; the conceptual surface is the README and `DESIGN.md`.
- The managed-block adoption and preview-first invariants can be tested against one shell environment (`tests/*.bats` in a temp HOME).

### Negative
- The tool is not directly useful on Linux machines, which is a real cost for teams that mix OSes.
- Users on unusual macOS setups (non-Homebrew, third-party package managers) are outside the supported range.

### Risks
- **Pressure to add Linux.** Real demand may appear. The response is either a proper ADR reversing this one, or a separate project that uses `DESIGN.md` as its starting contract.
