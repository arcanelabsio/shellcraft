# Architecture Decision Records — Shellcraft

Numbered records of architectural decisions in this repo. Each ADR captures the context, the options considered, and the decision taken, so future-us remember why the code looks the way it does.

## Conventions

- Numbering is sequential, zero-padded to 4 digits (`ADR-0001`, `ADR-0002`).
- Status is one of `Proposed`, `Accepted`, `Superseded`, `Deprecated`.
- When an org-level pattern applies, set `applies_pattern: PTRN-NNN` in the frontmatter — see [arcanelabsio-patterns](https://github.com/arcanelabsio/arcanelabsio-patterns).
- ADRs are immutable after acceptance. Supersede rather than edit.

## Index

- [ADR-0001](0001-preview-first-default.md) — `--plan` is the default; apply is explicit.
- [ADR-0002](0002-managed-block-dotfile-adoption.md) — Dotfiles are adopted via single include block, never overwritten.
- [ADR-0003](0003-macos-homebrew-only-scope.md) — macOS + Homebrew only; Linux, paid tools, sign-in defaults are out of scope.
