# Contributing

Thanks for improving this project. This document explains how the codebase is structured, what kinds of contributions are welcome, and the conventions you must follow to keep the script safe and idempotent.

---

## What belongs here

This repo is intentionally narrow in scope. Contributions should fit one of these categories:

| Category | Examples |
|----------|---------|
| **New CLI tools** | Adding a tool to the setup script + exercises |
| **Script bugs** | Incorrect PATH handling, broken idempotency, verification failures |
| **Config improvements** | Better defaults in `.zshrc`, `.gitconfig`, `.tmux.conf` |
| **New exercises** | New sections or days in `exercises/terminal-exercises.md` or `exercises/k8s-exercises.md` |
| **Exercise fixes** | Outdated commands, broken examples, unclear instructions |
| **Compatibility** | macOS version or architecture issues |

**Out of scope:** paid tools, tools requiring account sign-up, Linux support, GUI apps, package managers other than Homebrew.

---

## Adding a new CLI tool

This is the most common contribution. There are four touch points.

### 1. Add to `BREW_PACKAGES`

`setup-my-mac.sh` line ~278:

```bash
BREW_PACKAGES=(... existing tools ... your-new-tool)
```

The install loop, upgrade check, and verification loop all iterate this array automatically — you do not write separate install or verify calls.

### 2. Add to `get_tool_cmd()` if needed

If the tool's binary name differs from its Homebrew formula name, add a case:

```bash
get_tool_cmd() {
    case "$1" in
        ripgrep)      echo "rg" ;;
        git-delta)    echo "delta" ;;
        your-formula) echo "actual-binary" ;;  # add here
        *)            echo "$1" ;;
    esac
}
```

If the binary name matches the formula name (e.g. `jq` → `jq`), skip this step.

> **Why a `case` statement?** macOS ships bash 3.2, which does not support `declare -A` associative arrays. The script must remain compatible with the system bash — do not introduce bash 4+ syntax.

### 3. Add to README tool table

`README.md`, in the "CLI Tools" table:

```markdown
| `your-tool` | replaces | What it does in one sentence |
```

If the tool replaces a built-in, name the built-in in the second column. If it doesn't replace anything, use `—`.

### 4. Add exercises

At minimum, add a subsection to the relevant day in `exercises/terminal-exercises.md`. For a tool with significant surface area, a new day or a section in `exercises/k8s-exercises.md` may be appropriate. Follow the exercise format described below.

---

## Script conventions

### Logging helpers

Every meaningful action must use one of these — never use bare `echo`:

```bash
info "Installing thing..."          # blue ▸  — action in progress
success "thing installed"           # green ✔ — counts toward pass total
warn "thing not found, skipping"    # yellow ⚠ — non-fatal, logged
fail "thing installation failed"    # red ✘   — counts toward fail total
skip "thing"                        # dim ⊘   — already done, counts toward skip total
section "N/7 — Stage Name"          # box header — use for top-level stages only
troubleshoot "Run: brew install x"  # magenta 💡 — always pair with fail()
```

### Verify helpers

After any install or config write, verify success explicitly:

```bash
# For checking a command exists (used in the section 3 loop automatically):
verify_cmd "name (cmd)" "cmd" "troubleshoot hint"

# For any other condition (file exists, config value set, etc.):
verify "description" "shell expression that returns 0/1" "troubleshoot hint"
```

`verify()` swallows stdout/stderr — the expression only needs to exit 0 or non-zero.

### Idempotency

Every action must be safe to run twice on the same machine. The pattern is:

```bash
if <already done check>; then
    skip "thing"
else
    info "Doing thing..."
    if <do it>; then
        success "thing done"
    else
        fail "thing failed"
        troubleshoot "hint"
    fi
fi
```

`brew list "$pkg"` is the standard already-done check for Homebrew packages. For config files, check for a marker string (`grep -q "marker" ~/.zshrc`).

### No `set -e`

The script uses `set -uo pipefail` but deliberately omits `set -e`. This is intentional — failures are caught by `verify()` calls and reported in the final summary, rather than halting mid-run. Do not add `set -e`.

### Bash 3.2 compatibility

macOS ships with bash 3.2 and will not update it. The script must run under `/bin/bash` on a stock macOS machine. Forbidden:

- `declare -A` (associative arrays — use a `case` statement)
- `mapfile` / `readarray`
- `<<<` with process substitution in some contexts
- Bash 4+ string operators like `${var^^}`

Test with `bash --version` — if it prints `3.2`, your syntax is compatible.

---

## Exercise file conventions

All exercise files follow the same format. Match it exactly.

### Section header

```markdown
### D.N — Tool: What this section teaches

Short explanation of the concept — one or two sentences. Name the key function or flag.
```

### Code block

````markdown
```zsh
# Comment explaining the pattern
command --flag arg          # inline note on what this does

# Group related commands with a blank line between groups
another command
```
````

Rules:
- Language tag is always `zsh`
- Every non-obvious command has a trailing `# comment`
- Show the minimal version first, then variations — don't start with the most complex form
- No `sudo` commands in exercises
- Paths use `~` not `/Users/yourname`
- Sample data lives in `~/data/` — create it with a heredoc in the "Sample data" section

### Exercise prompt

Every section ends with exactly one exercise:

```markdown
**Exercise:** Imperative instruction describing what to do. Be specific enough that success is unambiguous.
```

Avoid exercises that require network access or external accounts. All exercises must work offline against local files where possible.

### Checkpoint

Each day ends with a checkbox list:

```markdown
### Day N Checkpoint

- [ ] Completed thing 1
- [ ] Completed thing 2
```

One checkbox per major concept in the day, not per subsection.

---

## Testing your changes

### Script changes

The safest way to test `setup-my-mac.sh` changes is to **re-run on an existing configured machine**. The idempotency design means this is safe — installed tools will be skipped, and your new stage will run for real.

```bash
./setup-my-mac.sh 2>&1 | tee /tmp/test-run.log
```

Check the final summary for any unexpected failures. Also check the log:

```bash
grep "FAIL\|WARN" /tmp/test-run.log
```

For config file changes (`.zshrc`, `.gitconfig`), back up your current files before testing:

```bash
cp ~/.zshrc ~/.zshrc.bak
./setup-my-mac.sh
diff ~/.zshrc.bak ~/.zshrc
```

### Exercise changes

Run every command in a new terminal session with no state from prior exercises. If a command relies on a previous step (e.g. a file created earlier in the day), say so explicitly in a comment.

---

## Pull request checklist

- [ ] Tool is added to `BREW_PACKAGES` (if applicable)
- [ ] `get_tool_cmd()` updated if binary name ≠ formula name
- [ ] README tool table updated
- [ ] `verify_cmd` or `verify` call exists after any new install
- [ ] New code uses `info`/`success`/`fail`/`skip` — no bare `echo`
- [ ] No `bash 4+` syntax
- [ ] Script re-runs cleanly on an already-configured machine (no failures, appropriate skips)
- [ ] Exercises follow the section/code block/exercise/checkpoint format
- [ ] All exercise commands tested locally
