# Mac Developer CLI Power Setup

> One script. Every tool. Apple Silicon + Intel. No prompts.

Run it on a fresh Mac to get a fully configured developer terminal in under 10 minutes. Run it again on an existing Mac to upgrade everything to the latest version.

```bash
# Clone the repo (once) 
git clone git@github.com:ajitgunturi/shellcraft.git

cd shellcraft
chmod +x setup-my-mac.sh
./setup-my-mac.sh
```

---

## What You Get

A terminal that looks and behaves like this:

- **Powerlevel10k** prompt — git status, exit codes, execution time, directory depth, all at a glance
- **Syntax highlighting** as you type — red for invalid commands, green for valid ones
- **Autosuggestions** from history — accept with `→` or `Ctrl+Space`
- **Fuzzy everything** — history, files, branches, commits, diffs, stashes, all via `fzf`
- **Smart jumps** — `z proj` instead of `cd ~/workspace/my-project`
- **Better defaults** — `ls` shows icons, `cat` highlights syntax, `grep` is instant, `diff` is side-by-side

---

## What Gets Installed

### CLI Tools (via Homebrew)

| Tool | Replaces | What it does |
|------|----------|--------------|
| `eza` | `ls` | File listing with icons, git status, tree view |
| `bat` | `cat` | Syntax-highlighted file viewing with line numbers |
| `ripgrep` (`rg`) | `grep` | Recursive search, respects `.gitignore`, very fast |
| `fd` | `find` | Simple, fast file finder with sane defaults |
| `fzf` | — | Fuzzy finder — layers on top of history, files, git |
| `zoxide` (`z`) | `cd` | Jump to directories by learned frequency |
| `git-delta` | `git diff` | Side-by-side diffs with syntax highlighting |
| `lazygit` | `git` TUI | Full terminal git interface |
| `git-absorb` | `git commit --fixup` | Auto-detect fixup commits from staged changes |
| `tmux` | Terminal tabs | Persistent sessions, split panes, detach/re-attach |
| `htop` | `top` | Interactive process monitor |
| `bat` | `cat` | Syntax-highlighted file viewing |
| `jq` | — | JSON processing on the command line |
| `tldr` | `man` | Practical command examples |
| `neovim` | `vim` | Modern vim |
| `tree` | — | Directory tree visualiser |
| `wget` | — | File downloader |
| `gnu-sed` (`gsed`) | BSD `sed` | GNU sed for script compatibility |

### Zsh Stack

| Component | Role |
|-----------|------|
| **Oh My Zsh** | Plugin framework and theme engine |
| **Powerlevel10k** | Prompt theme — instant prompt, no lag |
| **zsh-autosuggestions** | Fish-style inline history suggestions |
| **zsh-syntax-highlighting** | Command line syntax colouring |
| **MesloLGS Nerd Font** | Font required for Powerlevel10k icons |

### Config Files Written

| File | What it configures |
|------|--------------------|
| `~/.zshrc` | Shell, plugins, history, fzf, all aliases and functions |
| `~/.gitconfig` | User info, delta pager, rerere, useful aliases |
| `~/.gitignore_global` | macOS, editor, env, node, python ignores |
| `~/.tmux.conf` | Prefix `Ctrl+a`, vim pane navigation, clipboard, status bar |
| `~/.oh-my-zsh/custom/aliases.zsh` | Your personal aliases (never overwritten on re-run) |

---

## Key Bindings

### fzf

| Binding | Action |
|---------|--------|
| `Ctrl+R` | Fuzzy search command history — `Ctrl+Y` copies without running |
| `Ctrl+T` | Fuzzy file picker — inserts path at cursor |
| `Alt+C` | Fuzzy `cd` — jump to any subdirectory |
| `Ctrl+Space` | Accept autosuggestion |
| `→` | Accept autosuggestion (alternative) |
| `**<Tab>` | Fuzzy completion for current argument |

### Git Fuzzy Shortcuts

| Alias | Full name | Action |
|-------|-----------|--------|
| `gb` | `fgb` | Fuzzy branch switch with log preview |
| `gl` | `fgl` | Fuzzy log browser — copies selected hash to clipboard |
| `ga` | `fga` | Fuzzy interactive `git add` — `Tab` to multi-select |
| `gs` | `fgs` | Fuzzy stash browser with diff preview |
| `gd` | `fgd` | Fuzzy diff browser — changed files with delta preview |

### tmux (prefix = `Ctrl+a`)

| Binding | Action |
|---------|--------|
| `Ctrl+a \|` | Vertical split |
| `Ctrl+a -` | Horizontal split |
| `Ctrl+a h/j/k/l` | Navigate panes (vim keys) |
| `Ctrl+a z` | Zoom current pane to full screen |
| `Ctrl+a c` | New window |
| `Ctrl+a ,` | Rename window |
| `Ctrl+a w` | Fuzzy window/session picker |
| `Ctrl+a [` | Scroll / copy mode (`v` to select, `y` to yank) |
| `Ctrl+a d` | Detach session (keeps running in background) |
| `Ctrl+a r` | Reload `~/.tmux.conf` live |

---

## Shell Aliases & Functions

### Command Replacements

```zsh
ls    → eza --icons --group-directories-first
ll    → eza -la --icons --group-directories-first
lt    → eza -la --icons --tree --level=2
la    → eza -a  --icons --group-directories-first
cat   → bat --paging=never
grep  → rg
find  → fd
top   → htop
diff  → delta
```

### Navigation

```zsh
..        cd ..
...       cd ../..
....      cd ../../..
z <frag>  jump to a learned directory by fragment
zi        interactive fuzzy directory picker
cls       clear
```

### Git Aliases (in `.gitconfig`)

```zsh
git st       status -sb
git lg       log --oneline --graph --all -20
git ll       detailed log with date and author
git co       checkout
git cm       commit -m
git ca       commit --amend --no-edit
git undo     reset --soft HEAD~1   (uncommit, keep changes staged)
git wip      add -A && commit -m 'WIP'
git unwip    reset HEAD~1
git recent   branches sorted by last commit date
git cleanup  delete branches merged into main
git bl       blame -w -C -C -C    (ignore whitespace + move detection)
```

### Utility Functions

```zsh
mkcd <dir>       mkdir -p <dir> && cd into it
extract <file>   extract any archive (.tar.gz, .zip, .7z, ...)
note <text>      append timestamped note to ~/notes.md
```

### Shell Shortcuts

```zsh
reload    source ~/.zshrc
h         history | tail -30
hg <term> history | rg <term>
ports     lsof -i listening ports
myip      your public IP
path      PATH entries one per line
brewup    brew update && upgrade && cleanup
```

---

## History Configuration

100,000 entries, shared across sessions, with these options active:

| Option | Effect |
|--------|--------|
| `SHARE_HISTORY` | All open terminals see each other's commands in real time |
| `HIST_IGNORE_ALL_DUPS` | No duplicate entries |
| `HIST_IGNORE_SPACE` | Commands prefixed with a space are not saved (useful for secrets) |
| `INC_APPEND_HISTORY` | Written immediately, not on shell exit |
| `EXTENDED_HISTORY` | Timestamps stored with every entry |

---

## How It Works

```
setup-my-mac.sh (stored anywhere, e.g. ~/workspace/setup-my-workstation/)
│
│   ← script immediately cds to $HOME; all writes use absolute paths
│
├── 1/7  Xcode Command Line Tools     softwareupdate or xcode-select --install
├── 2/7  Homebrew                     install + brew update, PATH for arm64 + x86
├── 3/7  CLI Tools                    brew install missing, brew upgrade outdated
├── 4/7  Oh My Zsh                    install or git pull to update
├── 5/7  Zsh Plugins & Theme          install or git pull: p10k, autosuggestions,
│                                     syntax-highlighting, MesloLGS Nerd Font
├── 6/7  Generating Config Files      write .zshrc, .gitconfig, .gitignore_global,
│                                     .tmux.conf directly to $HOME;
│                                     aliases.zsh → $ZSH_CUSTOM (auto-loaded, preserved)
└── 7/7  Final Health Check           verify every component, print pass/fail/skip report
```

Each stage:
- Verifies success after running
- Prints a troubleshooting hint on any failure
- Is fully **idempotent** — safe to re-run; existing installs are upgraded, not re-installed
- Backs up any config file it would overwrite to `~/.dotfiles-backup/<timestamp>/`
- Writes all output files to absolute `$HOME`-based paths — **location of the script does not matter**

---

## Upgrade Behaviour

Running the script on an already-configured machine:

| Component | Upgrade mechanism |
|-----------|-------------------|
| Homebrew | `brew update` |
| CLI packages | `brew outdated` diff → `brew upgrade` for changed packages only |
| Oh My Zsh | `git pull` in `~/.oh-my-zsh` |
| Powerlevel10k | `git pull` in `$ZSH_CUSTOM/themes/powerlevel10k` |
| zsh-autosuggestions | `git pull` in `$ZSH_CUSTOM/plugins/zsh-autosuggestions` |
| zsh-syntax-highlighting | `git pull` in `$ZSH_CUSTOM/plugins/zsh-syntax-highlighting` |
| MesloLGS Nerd Font | `brew upgrade --cask` |
| Config files | Rewritten from template (backup created first) |
| `aliases.zsh` | **Never overwritten** — your customisations are preserved |

---

## Compatibility

| | |
|-|-|
| **macOS** | 12 Monterey · 13 Ventura · 14 Sonoma · 15 Sequoia |
| **Architecture** | Apple Silicon (arm64) · Intel (x86_64) |
| **Shell** | Runs under system `/bin/bash` 3.2 — no bash 4+ required |
| **Run location** | Anywhere — script `cd`s to `$HOME` automatically before doing any work |
| **Sudo** | Required once at start; kept alive for the duration |
| **Network** | Required — downloads Homebrew, OMZ, plugins, fonts |
| **Disk** | ~1–2 GB for all tools and fonts |

> **Note on bash 3.2:** macOS ships with bash 3.2 (GPL v2) and will not update it. This script avoids `declare -A` associative arrays and other bash 4+ features specifically to remain compatible with the system shell.

---

## After Running

```bash
# 1. Restart your terminal (or source ~/.zshrc)
source ~/.zshrc

# 2. Set your terminal font to "MesloLGS NF"
#    iTerm2: Preferences → Profiles → Text → Font
#    Terminal.app: Preferences → Profiles → Font

# 3. Configure your prompt (optional — p10k ships with a wizard)
p10k configure

# 4. Set your git identity
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"

# 5. Add your own shortcuts
vim ~/.oh-my-zsh/custom/aliases.zsh
```

---

## Customisation

**Add your own aliases** — the only file you should edit freely:

```bash
~/.oh-my-zsh/custom/aliases.zsh
```

It is auto-loaded by Oh My Zsh on every shell start and is **never overwritten** when you re-run `setup-my-mac.sh`.

**Add your own Oh My Zsh plugins** — drop any `*.zsh` file into:

```bash
~/.oh-my-zsh/custom/
```

Oh My Zsh sources all `*.zsh` files in this directory automatically.

---

## Files in This Repository

```
setup-my-mac.sh          Main setup and upgrade script
terminal-exercises.md    5-day hands-on exercise programme for every tool
README.md                This file
```

---

## Log & Troubleshooting

The full log of every action is written to:

```
~/.mac-dev-setup.log
```

If a step fails, the script prints a specific troubleshooting hint inline. To see everything:

```bash
cat ~/.mac-dev-setup.log
```

Common fixes:

| Problem | Fix |
|---------|-----|
| `brew: command not found` after install | Run `eval "$(/opt/homebrew/bin/brew shellenv)"` then retry |
| Powerlevel10k shows boxes instead of icons | Set terminal font to **MesloLGS NF** |
| `p10k` prompt not loading | Run `p10k configure` |
| Xcode CLI tools hang | Run `sudo xcode-select --reset` |
| A package fails to upgrade | Run `brew doctor` then `brew upgrade <package>` manually |

---

## License

MIT — use freely, modify freely, share freely.
