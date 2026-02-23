# 6-Day Terminal Mastery Exercises
> Tools installed: eza · bat · fd · rg · fzf · zoxide · tmux · lazygit · git-delta · htop · tldr · jq · yq · zsh-autosuggestions · zsh-syntax-highlighting · powerlevel10k

Each day builds on the previous. Budget ~30 minutes per session.

---

## Day 1 — Ground Floor: Navigation, Viewing, Searching

**Goal:** Replace the commands you already know with faster equivalents.

### 1.1 — eza (better `ls`)

```zsh
ls                        # icons, dirs grouped first
ll                        # long list: perms, size, date, owner
la                        # all files including hidden
lt                        # tree view, 2 levels deep
lt --level=3              # go deeper

# Sort tricks
eza -la --sort=size       # largest files last
eza -la --sort=modified   # most recently changed last
```

**Exercise:** Run `lt` in your `~/workspace` directory. Find the deepest nested file.

---

### 1.2 — bat (better `cat`)

```zsh
bat ~/.zshrc              # syntax highlighted, line numbers, git changes marked
bat -n ~/.zshrc           # line numbers only
bat -p ~/.zshrc           # plain — no decorations (good for piping)
bat --list-themes         # see available themes
bat --theme=Dracula ~/.zshrc

# bat as a pager for man pages
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
man git                   # try it
```

**Exercise:** Use `bat` to view your `.gitconfig`. Notice git-changed lines are highlighted in the gutter.

---

### 1.3 — fd (better `find`)

```zsh
fd                        # list everything in current dir (respects .gitignore)
fd .zsh ~                 # files ending in .zsh under home
fd -t f .md               # only files (-t f) with .md extension
fd -t d src               # only directories named 'src'
fd -H .env                # include hidden files (-H)
fd -e sh ~ --exec bat {}  # find all .sh files and bat-view them

# With a max depth
fd -d 2 . ~/workspace     # max 2 levels deep
```

**Exercise:** Find all `.zsh` files under `~/.oh-my-zsh/custom`. Count them.

---

### 1.4 — rg (better `grep`)

```zsh
rg "alias"                # search current dir recursively
rg "alias" ~/.zshrc       # search specific file
rg -i "homebrew" ~        # case insensitive
rg -l "export" ~          # list files that match, not lines
rg -c "function" ~/.zshrc # count matches per file
rg --type zsh "plugin"    # only in .zsh files

# Context lines (like grep -C)
rg -C 2 "ZSH_THEME" ~/.zshrc   # 2 lines before and after
```

**Exercise:** Search your `.zshrc` for every line containing "fzf". Then search `~/.oh-my-zsh` for files that contain "powerlevel10k" — only list filenames.

---

### 1.5 — zoxide (smarter `cd`)

```zsh
# First, build up zoxide's database by navigating normally:
cd ~/workspace/family-finances
cd ~/workspace/meet-mind
cd ~/.oh-my-zsh/custom

# Now jump without full paths:
z family                  # matches ~/workspace/family-finances
z custom                  # matches ~/.oh-my-zsh/custom
z meet                    # matches ~/workspace/meet-mind

# zi = interactive fuzzy picker of your history
zi                        # opens fzf over your visited dirs, Enter to jump
```

**Exercise:** Visit 3 different directories with `cd`, then use `z` with a fragment to jump back to each one.

---

### Day 1 Checkpoint

- [ ] `ll` feels natural instead of `ls -la`
- [ ] You used `bat` to view a file
- [ ] You found a file with `fd` without using `find`
- [ ] You searched file contents with `rg` without using `grep`
- [ ] You jumped to a directory with `z`

---

## Day 2 — FZF: The Fuzzy Layer on Everything

**Goal:** Make `fzf` your primary interface for history, files, and shell navigation.

### 2.1 — The Three Core Key Bindings

```zsh
# Ctrl+R — fuzzy history search
# Type a fragment of any past command. Arrow keys navigate. Enter runs it.
# Ctrl+Y copies the selected command to clipboard without running.

# Ctrl+T — fuzzy file picker
# Inserts the selected file path at your cursor position.
# Useful: type `bat ` then press Ctrl+T to pick a file to view.

# Alt+C — fuzzy cd
# Opens fzf over subdirectories, Enter to cd into the selected one.
```

**Exercise:** Press `Ctrl+R` and type `git`. Browse your git command history. Press `Ctrl+C` to cancel without running anything.

---

### 2.2 — FZF Tab Completion

```zsh
# After installing fzf, ** triggers fuzzy completion
cd **<TAB>                # fuzzy pick a directory
bat **<TAB>               # fuzzy pick a file to view
kill **<TAB>              # fuzzy pick a process to kill
ssh **<TAB>               # fuzzy pick from known hosts
unset **<TAB>             # fuzzy pick an env variable to unset
export **<TAB>            # same
```

**Exercise:** Type `bat **` then press Tab. Navigate with arrow keys. Press Enter to open the file.

---

### 2.3 — FZF Inside Commands (piping)

```zsh
# Pipe anything into fzf to make it interactive
ls ~ | fzf               # pick a file from home
history | fzf            # browse full history interactively

# Preview window
ls ~ | fzf --preview 'bat --color=always {}'       # preview files as you browse
fd -t f . ~ | fzf --preview 'bat --color=always {}'

# Multi-select with Tab
fd -t f . ~/workspace | fzf --multi     # Tab to mark, Enter to output all selected
```

**Exercise:** Run `fd -t f . ~/.oh-my-zsh/custom | fzf --preview 'bat --color=always {}'`. Browse through the plugin files with a live preview.

---

### 2.4 — Your Custom Git FZF Aliases

These are defined in your `.zshrc`:

```zsh
# In a git repo:
gb    # (fgb) fuzzy branch switch — pick a branch and check it out
gl    # (fgl) fuzzy log browser — Enter copies the commit hash to clipboard
ga    # (fga) fuzzy git add — Tab multi-selects files to stage
gs    # (fgs) fuzzy stash browser — preview stash diffs
gd    # (fgd) fuzzy diff browser — browse changed files with delta preview
```

**Exercise:** In any git repo, run `gl`. Browse the log. Select a commit and confirm the hash is in your clipboard with `pbpaste`.

---

### 2.5 — FZF Environment Variable Tricks

```zsh
# Inspect what FZF settings are active
echo $FZF_DEFAULT_COMMAND        # what it uses to list files
echo $FZF_CTRL_T_COMMAND         # what Ctrl+T lists
echo $FZF_ALT_C_COMMAND          # what Alt+C lists

# Temporarily override for one session
export FZF_DEFAULT_OPTS="--height=60% --border"
fzf                              # see the difference
```

**Exercise:** Run `echo $FZF_CTRL_R_OPTS` to see your history search config. Identify which key copies a command to clipboard without running it (hint: look for `ctrl-y`).

---

### Day 2 Checkpoint

- [ ] Used `Ctrl+R` to find and re-run a past command
- [ ] Used `Ctrl+T` to insert a file path mid-command
- [ ] Tried `**<TAB>` completion at least once
- [ ] Used `gl` or `ga` in a git repository
- [ ] Piped something into `fzf` manually

---

## Day 3 — tmux: Working in Panes and Sessions

**Goal:** Stop closing terminals. Detach and re-attach. Split your screen.

### 3.1 — Session Basics

```zsh
tmux                          # start a new unnamed session
tmux new -s work              # start a named session called 'work'
tmux ls                       # list all sessions (from outside tmux)

# Inside tmux — all commands start with Ctrl+a (your prefix)
# Ctrl+a d       detach (session keeps running in background)
# Ctrl+a $       rename current session
# Ctrl+a s       fuzzy switch between sessions

tmux attach -t work           # re-attach to 'work' session
tmux attach                   # re-attach to most recent session
```

**Exercise:** Create a session named `dev`. Run `htop` inside it. Detach with `Ctrl+a d`. From the normal shell, run `tmux ls` to confirm it's still running. Re-attach.

---

### 3.2 — Windows (tabs inside a session)

```zsh
# Ctrl+a c       create a new window
# Ctrl+a ,       rename current window
# Ctrl+a w       fuzzy window picker
# Ctrl+a n       next window
# Ctrl+a p       previous window
# Ctrl+a 1-9     jump to window by number
# Ctrl+a &       close current window (confirms)
```

**Exercise:** Inside a tmux session, create 3 windows. Name them `edit`, `run`, `logs`. Practice switching between them with `Ctrl+a w` and by number.

---

### 3.3 — Panes (splits inside a window)

```zsh
# Ctrl+a |       vertical split (side by side)
# Ctrl+a -       horizontal split (top and bottom)
# Ctrl+a h/j/k/l navigate panes (vim keys)
# Ctrl+a z       zoom/unzoom current pane (full screen toggle)
# Ctrl+a x       close current pane
# Ctrl+a {       swap pane left
# Ctrl+a }       swap pane right
# Ctrl+a H/J/K/L resize pane (hold to repeat)
```

**Exercise:** Split your window into 3 panes: one vertical split, then split the right pane horizontally. Run a different command in each: `htop`, `ll ~`, and `bat ~/.zshrc`. Practice navigating with `Ctrl+a h/j/k/l`.

---

### 3.4 — Copy Mode (scroll and copy text)

```zsh
# Ctrl+a [       enter copy mode (scroll with arrow keys or vim keys)
# q              exit copy mode
# In copy mode:
#   v            begin selection (vim style)
#   y            yank selection to clipboard (via pbcopy)
#   /            search forward
#   ?            search backward
#   n            next match
#   N            previous match
```

**Exercise:** Run a command that produces many lines (`ll /opt/homebrew/bin`). Enter copy mode with `Ctrl+a [`. Scroll up with `k`. Search for `git` with `/git`. Press `y` to yank a line.

---

### 3.5 — Config Reload

```zsh
# After editing ~/.tmux.conf:
Ctrl+a r          # reloads config and shows "Config reloaded!"

# Your current .tmux.conf key settings worth memorizing:
# prefix = Ctrl+a  (not the default Ctrl+b)
# splits open in the same directory you're already in
# mouse is on — you can click panes and scroll
```

**Exercise:** Edit `~/.tmux.conf`. Add `set -g status-bg colour235` on the last line. Reload with `Ctrl+a r` and observe the status bar change.

---

### Day 3 Checkpoint

- [ ] Created a named tmux session and detached/re-attached
- [ ] Created 3 named windows in one session
- [ ] Split a window into 3 panes and navigated between them
- [ ] Used copy mode to scroll and yank text
- [ ] Reloaded tmux config live

---

## Day 4 — Git Power Workflow

**Goal:** Make every git operation faster — staging, browsing, diffing, fixing.

### 4.1 — lazygit Full Tour

```zsh
lazygit               # open in any git repo
```

Key bindings inside lazygit:

| Key | Action |
|-----|--------|
| `1-5` | Switch between panels (Status / Files / Branches / Commits / Stash) |
| `Space` | Stage/unstage file |
| `a` | Stage all files |
| `c` | Commit (opens editor) |
| `C` | Commit with custom message inline |
| `p` | Push |
| `P` | Pull |
| `b` | Branch panel — create, delete, checkout |
| `d` | Diff selected file |
| `e` | Open file in editor |
| `z` | Undo last action |
| `?` | Help / all keybindings |
| `q` | Quit |

**Exercise:** In a git repo with some changes, open `lazygit`. Stage individual files with Space. Write a commit message. Browse the commit log panel.

---

### 4.2 — git-delta (better diffs)

delta is set as your default pager in `.gitconfig`, so it's already active:

```zsh
git diff              # side-by-side diff with line numbers, syntax highlighting
git show HEAD         # colored commit view
git log -p            # full patch log with delta rendering

# delta directly
delta file1.txt file2.txt    # compare two files

# Your .gitconfig delta config:
# side-by-side = true
# navigate = true (n/N to jump between diff sections)
# syntax-theme = Dracula
```

**Exercise:** Make a change to any file in a git repo. Run `git diff`. Use `n` and `N` to jump between changed hunks. Notice the side-by-side layout.

---

### 4.3 — Your .gitconfig Aliases

```zsh
git st          # status -sb (short branch format)
git lg          # oneline graph log, last 20 commits
git ll          # detailed log with date, author, subject
git co main     # checkout
git br          # branch list
git cm "msg"    # commit -m
git ca          # commit --amend --no-edit (fix last commit)
git undo        # reset --soft HEAD~1 (uncommit, keep changes staged)
git wip         # add -A + commit "WIP" in one shot
git unwip       # undo the WIP commit
git recent      # branches sorted by last commit date
git cleanup     # delete branches already merged into main
git stash-all   # stash including untracked files
git aliases     # list all your git aliases
```

**Exercise:** In a repo, run `git lg`. Then make a bad commit and use `git undo` to uncommit it while keeping your changes. Then use `ga` (your fzf alias) to re-stage just what you want.

---

### 4.4 — git-absorb (fixup commits automatically)

`git absorb` automatically identifies which staged changes belong to which previous commit and creates the right `fixup!` commits — then you rebase them in.

```zsh
# Workflow:
git log --oneline -5             # identify the commit to fix
# (edit the file to fix a bug introduced in a recent commit)
git add <fixed-file>             # stage the fix
git absorb                       # auto-creates fixup! commits
git rebase -i --autosquash HEAD~5   # squash fixups into their parents
```

**Exercise:** Make 2 commits in a test repo. Go back and fix something from the first commit. Stage the fix and run `git absorb --dry-run` to see what it would do.

---

### 4.5 — rerere (reuse recorded resolutions)

`rerere` is enabled in your `.gitconfig`. It records how you resolve merge conflicts so that if the same conflict appears again (common during rebases), it resolves it automatically.

```zsh
git config --global rerere.enabled    # verify: should print 'true'

# It works silently. After manually resolving a conflict:
git rerere                            # shows what was recorded
ls .git/rr-cache/                     # cached resolutions live here
```

**Exercise:** Run `git config --global --list | rg rerere` to confirm it's active. Run `git rerere status` in any repo to see its state.

---

### Day 4 Checkpoint

- [ ] Used lazygit to stage, commit, and browse log
- [ ] Viewed a `git diff` through delta with side-by-side layout
- [ ] Used at least 3 git aliases from `.gitconfig`
- [ ] Ran `git absorb --dry-run` on a staged fix
- [ ] Confirmed rerere is enabled

---

## Day 5 — Integration: Real Workflows + Make It Yours

**Goal:** Combine everything into fluid workflows. Customize your setup.

### 5.1 — The "Project Start" Workflow

Every time you start a work session, practice this sequence:

```zsh
# 1. Jump to project (zoxide)
z meet-mind           # or z family, etc.

# 2. Start (or re-attach) a named tmux session
tmux new -s meet 2>/dev/null || tmux attach -t meet

# 3. Set up windows (inside tmux)
# Ctrl+a c  → name it 'code'  (Ctrl+a ,)
# Ctrl+a c  → name it 'git'
# Ctrl+a c  → name it 'run'

# 4. In 'git' window, open lazygit
lazygit

# 5. In 'code' window, split and run your editor + bat for reference
# Ctrl+a |  → right pane: bat the file you're about to edit

# 6. In 'run' window, keep a shell ready for test runs
```

**Exercise:** Set up the full 3-window tmux session for one of your real projects. Keep it running. Practice detaching and re-attaching.

---

### 5.2 — The "Find Anything" Workflow

```zsh
# Find a file whose name you half-remember
fd "finance" ~/workspace          # filename fragment
fd -e md ~/workspace              # by extension

# Find code containing something
rg "TODO" ~/workspace             # all TODOs across projects
rg "def.*auth" ~/workspace        # functions with 'auth' in name
rg -l "import pandas"             # which files use pandas

# Combine fd + fzf + bat for exploration
fd -t f . ~/workspace | fzf --preview 'bat --color=always {}'
```

**Exercise:** Use `rg` to find all TODO comments across your entire `~/workspace`. Then use `fd | fzf` with preview to browse and read interesting files.

---

### 5.3 — The "History as Documentation" Workflow

Your history is set to 100,000 entries with deduplication and timestamps.

```zsh
# Review what you did recently
h                           # last 30 commands
history | rg "docker"       # everything you've ever run with docker
history | rg "git push"     # your push history

# Ctrl+R with multi-word search (fzf matches non-contiguous)
# Press Ctrl+R, then type: "brew install" — finds any brew install commands
# Type: "git commit main" — finds commits to main
```

**Exercise:** Search your history for every `brew install` command you've run. Then search for any command that touched a file in `~/workspace`.

---

### 5.4 — jq & yq: intro

```zsh
jq --version      # confirm jq is installed
yq --version      # confirm yq is installed

# Quick taste — prettify JSON
echo '{"name":"ajit","role":"dev"}' | jq .

# Quick taste — prettify YAML
echo 'name: ajit\nrole: dev' | yq .
```

**Exercise:** Run both version checks. Then prettify any `.json` file in your projects with `jq .` piped through `bat`. See Day 6 for a full deep-dive into both tools.

---

### 5.5 — Make It Yours: Custom Aliases

Your aliases file lives at `~/.oh-my-zsh/custom/aliases.zsh`. This is the one file you should customize freely — Oh My Zsh loads all `*.zsh` files in that directory automatically, so no source line is needed.

```zsh
bat ~/.oh-my-zsh/custom/aliases.zsh   # view the current file
```

Suggested additions (pick what fits your workflow):

```zsh
# --- Project shortcuts ---
alias proj="z workspace"
alias meet="z meet-mind"
alias fin="z family-finances"

# --- tmux shortcuts ---
alias tl="tmux ls"
alias ta="tmux attach -t"
alias tn="tmux new -s"

# --- Dev shortcuts ---
alias py="python3"
alias ve="python3 -m venv .venv && source .venv/bin/activate"
alias activate="source .venv/bin/activate"

# --- Safety nets ---
alias rm="rm -i"          # confirm before delete
alias cp="cp -i"          # confirm before overwrite

# --- Quick edits ---
alias zshconfig="bat ~/.zshrc"
alias myaliases="bat ~/.oh-my-zsh/custom/aliases.zsh"
alias editaliases="vim ~/.oh-my-zsh/custom/aliases.zsh && source ~/.oh-my-zsh/custom/aliases.zsh"
```

After editing, reload without restarting:

```zsh
reload              # your alias: source ~/.zshrc && echo '✔ Reloaded!'
```

**Exercise:** Add at least 3 aliases that match your real projects/workflow. Reload and test them.

---

### 5.6 — Version Your Customisations

Your configs (`~/.zshrc`, `~/.gitconfig`, `~/.tmux.conf`) are plain files at `$HOME` — the setup script regenerates them from its template on every run. Your only freely-edited file is:

```
~/.oh-my-zsh/custom/aliases.zsh   ← never overwritten by the script
```

To back it up, copy it into the `setup-my-workstation` repo — your personalisation lives alongside the script that generated your environment.

```zsh
cp ~/.oh-my-zsh/custom/aliases.zsh ~/workspace/setup-my-workstation/aliases.zsh

cd ~/workspace/setup-my-workstation
git st                                      # see what changed
git add aliases.zsh
git cm "add personal aliases"
git push
```

If you haven't pushed the repo to GitHub yet:

```zsh
cd ~/workspace/setup-my-workstation
gh repo create setup-my-workstation --private --source=. --push
```

On your next Mac, the full workflow becomes:

```zsh
git clone git@github.com:you/setup-my-workstation.git ~/workspace/setup-my-workstation
cp ~/workspace/setup-my-workstation/aliases.zsh ~/.oh-my-zsh/custom/aliases.zsh
~/workspace/setup-my-workstation/setup-my-mac.sh
```

**Exercise:** Copy your `aliases.zsh` into the `setup-my-workstation` repo. Commit and push it. Your environment is now fully reproducible from a single `git clone`.

---

### Day 5 Checkpoint

- [ ] Set up a full tmux workspace for a real project
- [ ] Used `rg` across your whole workspace to find something useful
- [ ] Searched history with `Ctrl+R` for multi-word fragments
- [ ] Verified `jq` and `yq` are installed
- [ ] Added personal aliases to `~/.oh-my-zsh/custom/aliases.zsh` and reloaded
- [ ] Backed up `aliases.zsh` to the `setup-my-workstation` repo and pushed

---

## Quick Reference Card

### Key Bindings
| Binding | Action |
|---------|--------|
| `Ctrl+R` | Fuzzy history search |
| `Ctrl+T` | Fuzzy file picker (inserts path) |
| `Alt+C` | Fuzzy cd |
| `Ctrl+Space` | Accept autosuggestion |
| `→` | Accept autosuggestion (alternative) |
| `**<Tab>` | Fuzzy completion for current command |

### Command Replacements
| Old | New | Why |
|-----|-----|-----|
| `ls` / `ls -la` | `ls` / `ll` | eza: icons, git status, colors |
| `cat` | `cat` / `bat` | bat: syntax highlight, line numbers |
| `grep` | `grep` / `rg` | ripgrep: faster, respects .gitignore |
| `find` | `find` / `fd` | fd: simpler syntax, faster |
| `cd` (repeat) | `z` | zoxide: learned jump |
| `top` | `top` / `htop` | htop: interactive, mouse support |
| `git diff` | `git diff` | same command, delta renders it |
| `man` | `tldr` | tldr: practical examples first |

### tmux Prefix = `Ctrl+a`
| Binding | Action |
|---------|--------|
| `d` | Detach session |
| `c` | New window |
| `,` | Rename window |
| `w` | Window picker |
| `\|` | Vertical split |
| `-` | Horizontal split |
| `h/j/k/l` | Navigate panes |
| `z` | Zoom pane toggle |
| `[` | Scroll / copy mode |
| `r` | Reload config |

### Git Aliases (your .gitconfig)
| Alias | Expands to |
|-------|-----------|
| `git st` | `status -sb` |
| `git lg` | `log --oneline --graph --all -20` |
| `git cm` | `commit -m` |
| `git ca` | `commit --amend --no-edit` |
| `git undo` | `reset --soft HEAD~1` |
| `git wip` | `add -A && commit -m 'WIP'` |
| `git recent` | branches by last commit date |
| `git cleanup` | delete merged branches |

### Git FZF Shortcuts (your .zshrc)
| Alias | Action |
|-------|--------|
| `gb` | Fuzzy branch switch |
| `gl` | Fuzzy log (copies hash) |
| `ga` | Fuzzy interactive add |
| `gs` | Fuzzy stash browser |
| `gd` | Fuzzy diff browser |

---

## Day 6 — jq & yq: Querying JSON and YAML Like a Pro

**Goal:** Slice, filter, reshape, group, and export structured data without leaving the terminal.

> **Setup check:**
> ```zsh
> jq --version    # should print jq-1.7 or newer
> yq --version    # should print v4.x (mikefarah/yq)
> ```

---

### Sample data files

Create these once and reuse them across all exercises below:

```zsh
mkdir -p ~/data

# ~/data/people.json — an array of objects
cat > ~/data/people.json <<'EOF'
[
  {"id": 1, "name": "Anjali",  "dept": "eng",     "level": "senior", "salary": 145000, "remote": true},
  {"id": 2, "name": "Ben",     "dept": "design",   "level": "mid",    "salary": 95000,  "remote": false},
  {"id": 3, "name": "Cleo",   "dept": "eng",      "level": "mid",    "salary": 110000, "remote": true},
  {"id": 4, "name": "Diego",  "dept": "eng",      "level": "junior", "salary": 82000,  "remote": false},
  {"id": 5, "name": "Erin",   "dept": "product",  "level": "senior", "salary": 138000, "remote": true},
  {"id": 6, "name": "Farrukh","dept": "design",   "level": "senior", "salary": 120000, "remote": true},
  {"id": 7, "name": "Gina",   "dept": "product",  "level": "junior", "salary": 78000,  "remote": false},
  {"id": 8, "name": "Hiro",   "dept": "eng",      "level": "senior", "salary": 155000, "remote": true}
]
EOF

# ~/data/services.yaml — multiple YAML documents in one file (multi-doc YAML)
cat > ~/data/services.yaml <<'EOF'
---
name: auth-service
port: 3001
replicas: 2
tags: [auth, critical]
env: {LOG_LEVEL: warn, TIMEOUT: "30s"}
---
name: billing-service
port: 3002
replicas: 1
tags: [billing]
env: {LOG_LEVEL: info, TIMEOUT: "60s"}
---
name: notification-service
port: 3003
replicas: 3
tags: [notify, async]
env: {LOG_LEVEL: debug, TIMEOUT: "10s"}
EOF
```

> **For Kubernetes-specific yq exercises** (querying manifests, patching deployments, bumping image tags), see [`k8s-exercises.md`](./k8s-exercises.md).

**Exercise:** Run `bat ~/data/people.json` and `bat ~/data/services.yaml` to confirm the files look right. Notice bat syntax-highlights both JSON and YAML automatically.

---

### 6.1 — jq: Basic Filters

The `.` operator is the identity — it passes input through unchanged. Every jq expression is a filter that transforms JSON.

```zsh
# Pretty-print (identity filter)
jq '.' ~/data/people.json

# Extract a single field from all array items
jq '.[].name' ~/data/people.json

# Extract a specific index
jq '.[0]' ~/data/people.json          # first person
jq '.[-1]' ~/data/people.json         # last person

# Slice the array
jq '.[2:5]' ~/data/people.json        # items at index 2, 3, 4

# Extract multiple fields at once (comma = run both filters)
jq '.[].name, .[].salary' ~/data/people.json

# Build a new object per item
jq '.[] | {name, dept}' ~/data/people.json

# Rename keys in the output object
jq '.[] | {person: .name, department: .dept, pay: .salary}' ~/data/people.json
```

**Exercise:** Extract just the `name` and `level` of every person as a new JSON object with those exact keys.

---

### 6.2 — jq: Filtering with `select()`

`select(condition)` passes an item through only if the condition is true — it's the `WHERE` clause of jq.

```zsh
# Remote workers only
jq '.[] | select(.remote == true)' ~/data/people.json

# Specific department
jq '.[] | select(.dept == "eng")' ~/data/people.json

# Salary above threshold
jq '.[] | select(.salary > 100000)' ~/data/people.json

# Combine conditions with `and` / `or`
jq '.[] | select(.dept == "eng" and .level == "senior")' ~/data/people.json

# Negate with `not`
jq '.[] | select(.remote | not)' ~/data/people.json

# String contains (test())
jq '.[] | select(.name | test("^[AE]"))' ~/data/people.json   # names starting with A or E
```

**Exercise:** Find all engineers earning more than $100k who work remotely. Print only their names.

---

### 6.3 — jq: `map()`, `sort_by()`, `unique_by()`

`map(f)` applies filter `f` to every element — equivalent to `[.[] | f]`.

```zsh
# map: transform every item
jq 'map(.name)' ~/data/people.json                  # array of names
jq 'map(select(.remote))' ~/data/people.json        # filter, keep as array
jq 'map(.salary) | add' ~/data/people.json          # sum all salaries

# Sort
jq 'sort_by(.salary)' ~/data/people.json            # ascending by salary
jq 'sort_by(.salary) | reverse' ~/data/people.json  # descending

# Sort by string field
jq 'sort_by(.name)' ~/data/people.json

# Unique — deduplicate
jq '[.[].dept] | unique' ~/data/people.json         # list of distinct departments

# unique_by — keep first occurrence of each group key
jq 'unique_by(.dept)' ~/data/people.json            # one rep per dept

# min / max
jq 'min_by(.salary) | {name, salary}' ~/data/people.json
jq 'max_by(.salary) | {name, salary}' ~/data/people.json
```

**Exercise:** Sort the people by salary (descending) and print a list of just `name: $salary` pairs.

---

### 6.4 — jq: `group_by()` and Aggregations

`group_by(.key)` splits an array into sub-arrays, one per distinct value of `.key`. Combine with `map` to aggregate.

```zsh
# Group by department — produces array of arrays
jq 'group_by(.dept)' ~/data/people.json

# Group and count headcount per dept
jq 'group_by(.dept) | map({dept: .[0].dept, count: length})' ~/data/people.json

# Group and sum salaries per dept
jq 'group_by(.dept) | map({
  dept: .[0].dept,
  headcount: length,
  total_salary: (map(.salary) | add),
  avg_salary: (map(.salary) | add / length)
})' ~/data/people.json

# Group by dept then level (nested grouping)
jq 'group_by(.dept) | map({
  dept: .[0].dept,
  by_level: (group_by(.level) | map({level: .[0].level, count: length}))
})' ~/data/people.json

# Top earner per department
jq 'group_by(.dept) | map(max_by(.salary) | {dept, name, salary})' ~/data/people.json
```

**Exercise:** Produce a department summary table: `{dept, headcount, avg_salary, remote_count}`. Sort by `avg_salary` descending.

---

### 6.5 — jq: Reshaping and Building Output

Use object construction `{}` and `reduce` to reshape data into any structure.

```zsh
# Turn array into a lookup map {name: salary}
jq '[.[] | {(.name): .salary}] | add' ~/data/people.json

# Same but {id: object} lookup
jq '[.[] | {(.id | tostring): .}] | add' ~/data/people.json

# Flatten nested paths
jq '.[] | {name, remote_str: (if .remote then "yes" else "no" end)}' ~/data/people.json

# reduce: running total
jq 'reduce .[] as $p (0; . + $p.salary)' ~/data/people.json   # total payroll

# Add a computed field to every item
jq 'map(. + {annual_bonus: (.salary * 0.1 | floor)})' ~/data/people.json

# Remove fields
jq 'map(del(.id, .remote))' ~/data/people.json

# Rename a key
jq 'map(. + {department: .dept} | del(.dept))' ~/data/people.json
```

**Exercise:** Add a `tax_bracket` field to every person: `"high"` if salary ≥ 120k, `"mid"` if ≥ 80k, `"low"` otherwise. Print the result as a compact array.

---

### 6.6 — jq: Output Formats and Export

```zsh
# -r (raw) — strip quotes from strings, useful for shell pipelines
jq -r '.[].name' ~/data/people.json            # names as plain text, one per line

# -c (compact) — one JSON object per line (NDJSON)
jq -c '.[]' ~/data/people.json

# -j (raw no newline) — join without trailing newline
jq -rj '.[].name + "\n"' ~/data/people.json

# @csv — export as CSV
jq -r '.[] | [.name, .dept, .level, .salary] | @csv' ~/data/people.json

# @tsv — tab-separated (better for `cut`, `awk`, spreadsheets)
jq -r '.[] | [.name, .dept, .salary] | @tsv' ~/data/people.json

# Add a header row then export to a real .csv file
jq -r '["name","dept","level","salary"], (.[] | [.name,.dept,.level,.salary]) | @csv' \
    ~/data/people.json > ~/data/people.csv

bat ~/data/people.csv

# @base64 — encode a field
jq -r '.[0].name | @base64' ~/data/people.json

# --arg — pass a shell variable into jq
TARGET_DEPT="eng"
jq --arg dept "$TARGET_DEPT" '.[] | select(.dept == $dept) | .name' ~/data/people.json

# --argjson — pass a number or boolean
jq --argjson min 100000 '.[] | select(.salary >= $min) | {name, salary}' ~/data/people.json

# --slurp (-s) — read multiple JSON inputs as a single array
echo '{"x":1}' > /tmp/a.json
echo '{"x":2}' > /tmp/b.json
jq -s '.' /tmp/a.json /tmp/b.json        # merges into one array

# --raw-input (-R) — treat each line as a JSON string
ls ~ | jq -R '.'                          # each filename becomes a JSON string
ls ~ | jq -R '.' | jq -s '.'             # collect into a JSON array of filenames
```

**Exercise:** Export `people.json` to a TSV with columns `name`, `dept`, `salary`. Open it with `bat`. Then re-import the file with `--slurp` and count how many rows you get.

---

### 6.7 — jq: Real-World Pipeline Patterns

```zsh
# Combine with fzf for interactive JSON browsing
jq -c '.[]' ~/data/people.json | fzf | jq .   # pick a record, pretty-print it

# Parse a log file (assumes NDJSON — one JSON object per line)
# Generate a fake NDJSON log first:
for i in $(seq 1 5); do
  echo "{\"ts\":\"2024-0$i-01\",\"level\":\"info\",\"msg\":\"request $i\",\"status\":200}"
done > ~/data/app.log
echo '{"ts":"2024-06-01","level":"error","msg":"timeout","status":504}' >> ~/data/app.log

# Filter errors from a log
jq -c 'select(.level == "error")' ~/data/app.log

# Count by status code
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' ~/data/app.log

# Combine rg + jq: find lines matching a pattern, parse as JSON
rg '"level":"error"' ~/data/app.log | jq '{ts, msg}'

# Pipe curl output through jq (replace URL with any public API)
# curl -s 'https://api.github.com/repos/stedolan/jq/releases' | \
#   jq 'map({tag: .tag_name, date: .published_at}) | .[0:3]'
```

**Exercise:** From `app.log`, produce a summary `{total_requests, error_count, error_rate_pct}`.

---

### 6.8 — yq: YAML Filtering (same syntax as jq)

`yq` uses the exact same filter syntax as `jq` but operates on YAML files. The key difference: `services.yaml` is a **multi-document** YAML file (three `---` separated documents). Filters apply to each document in turn.

```zsh
# Pretty-print — all three documents, separated by ---
yq '.' ~/data/services.yaml

# yq can also read JSON directly — same filters work
yq '.[0].name' ~/data/people.json

# Extract a field — applied to every document
yq '.name' ~/data/services.yaml           # all three names
yq '.port' ~/data/services.yaml           # all three ports

# Target a specific document by index
yq 'select(document_index == 0)' ~/data/services.yaml    # first doc only
yq 'select(document_index == 1) | .name' ~/data/services.yaml

# Filter documents by condition
yq 'select(.replicas > 1)' ~/data/services.yaml
yq 'select(.replicas > 1) | .name' ~/data/services.yaml

# Nested field (the env map)
yq '.env.LOG_LEVEL' ~/data/services.yaml          # from all docs
yq 'select(.name == "billing-service") | .env.TIMEOUT' ~/data/services.yaml

# Array field (tags)
yq '.tags[]' ~/data/services.yaml                  # every tag across all docs
yq 'select(document_index == 0) | .tags[]' ~/data/services.yaml

# Check if a tag is present
yq 'select(.tags[] == "critical") | .name' ~/data/services.yaml
```

**Exercise:** Find every service with `LOG_LEVEL` set to `debug`. Print `name: port`.

---

### 6.9 — yq: Editing YAML In-Place

`yq -i` edits a file in-place — like `sed -i` but for structured YAML. It parses and re-serialises cleanly, so comments and structure are preserved. In multi-doc YAML, edits apply to every matching document unless you scope with `select()`.

```zsh
# Work on a copy so the original stays intact
cp ~/data/services.yaml /tmp/services-edit.yaml

# Update a scalar across all documents
yq -i '.replicas += 1' /tmp/services-edit.yaml         # bump every service by 1
yq '.replicas' /tmp/services-edit.yaml                 # verify

# Update only a specific service
yq -i '(select(.name == "billing-service").replicas) = 4' /tmp/services-edit.yaml

# Update a nested map value
yq -i '(select(.name == "auth-service").env.LOG_LEVEL) = "debug"' /tmp/services-edit.yaml

# Add a new top-level field to all documents
yq -i '.enabled = true' /tmp/services-edit.yaml

# Add a new field to only one document
yq -i '(select(.name == "billing-service").owner) = "finance-team"' /tmp/services-edit.yaml

# Append a tag to an array
yq -i '(select(.name == "billing-service").tags) += ["urgent"]' /tmp/services-edit.yaml

# Delete a field from all documents
yq -i 'del(.enabled)' /tmp/services-edit.yaml

# Delete a field from one document
yq -i 'del(select(.name == "billing-service").owner)' /tmp/services-edit.yaml

# Confirm changes with a diff
diff <(yq '.' ~/data/services.yaml) <(yq '.' /tmp/services-edit.yaml)
```

**Exercise:** On `/tmp/services-edit.yaml`: scale `notification-service` to 5 replicas, change all services' `TIMEOUT` to `"45s"`, and add a `monitored: true` field to services with `replicas >= 2`.

---

### 6.10 — yq: Format Conversion

`yq` converts freely between YAML, JSON, TOML, and XML. This is its killer feature over `jq`.

```zsh
# JSON → YAML
yq -P '.' ~/data/people.json            # -P = pretty YAML output
yq -P '.' ~/data/people.json > /tmp/people.yaml
bat /tmp/people.yaml

# YAML → JSON (single-document)
yq -o=json 'select(document_index == 0)' ~/data/services.yaml

# YAML → compact JSON (no indentation)
yq -o=json -I=0 'select(document_index == 0)' ~/data/services.yaml

# Multi-doc YAML → JSON array (wrap all docs in [])
yq -o=json '[.]' ~/data/services.yaml

# Pipe that JSON array into jq for further processing
yq -o=json '[.]' ~/data/services.yaml | jq 'map({name, port})'

# Multi-doc YAML → single-doc YAML array (same idea, YAML output)
yq -o=yaml '[.]' ~/data/services.yaml

# Merge a patch into a document
cat > /tmp/patch.yaml <<'EOF'
replicas: 10
env:
  LOG_LEVEL: error
EOF
yq '. *= load("/tmp/patch.yaml")' <(yq 'select(document_index == 0)' ~/data/services.yaml)

# Convert YAML and save as JSON
yq -o=json '[.]' ~/data/services.yaml > /tmp/services.json
bat /tmp/services.json
```

**Exercise:** Convert `services.yaml` to a JSON array and pipe into `jq` to produce `{name, port, replica_count}` for every service where `replicas >= 2`.

---

### 6.11 — yq: map(), group_by(), sort_by() on YAML arrays

`yq` supports the same collection operations as `jq`.

```zsh
# Using people.yaml (created in 6.10)
# List all names
yq '.[].name' /tmp/people.yaml

# Filter — remote workers only
yq '.[] | select(.remote == true) | .name' /tmp/people.yaml

# Sort by salary
yq 'sort_by(.salary) | .[].name' /tmp/people.yaml

# Map to new shape
yq 'map({"person": .name, "pay": .salary})' /tmp/people.yaml

# Group by dept and count
yq 'group_by(.dept) | map({"dept": .[0].dept, "count": length})' /tmp/people.yaml

# Services: sort by port number
yq 'sort_by(.port) | .[].name' ~/data/services.yaml

# Services: filter those with multiple replicas
yq 'select(.replicas > 1) | .name + " (" + (.replicas | tostring) + " replicas)"' \
    ~/data/services.yaml
```

**Exercise:** Using `/tmp/people.yaml`, group by `level` and output `{level, count, avg_salary}` sorted by `avg_salary` descending.

---

### 6.12 — Combining jq + yq in Real Workflows

```zsh
# Interactive YAML browsing: pick a service, pretty-print it
yq -o=json '[.]' ~/data/services.yaml | jq -c '.[]' | fzf | jq .

# Audit: which services are under-replicated (replicas < 2)?
yq 'select(.replicas < 2) | .name' ~/data/services.yaml

# Generate a formatted table of services (yq → jq → column)
yq -o=json '[.]' ~/data/services.yaml | \
  jq -r '["Service","Port","Replicas"], (.[] | [.name, (.port|tostring), (.replicas|tostring)]) | @tsv' | \
  column -t -s $'\t'

# Generate shell exports for every service's port
yq -o=json '[.]' ~/data/services.yaml | \
  jq -r '.[] | "export " + (.name | ascii_upcase | gsub("-"; "_")) + "_PORT=" + (.port|tostring)'

# Cross-reference: list remote workers alongside the service they might own
# (demonstrates combining two data sources via jq)
jq -r 'map(select(.remote)) | .[].name' ~/data/people.json | \
  while read name; do
    echo "$name → $(yq 'select(document_index == 0) | .name' ~/data/services.yaml)"
  done

# Validate: confirm every service has a port defined
yq -o=json '[.]' ~/data/services.yaml | \
  jq '.[] | {name, has_port: (.port != null)}'

# Export services data as CSV (yq to JSON, then jq to CSV)
yq -o=json '[.]' ~/data/services.yaml | \
  jq -r '["name","port","replicas"], (.[] | [.name, (.port|tostring), (.replicas|tostring)]) | @csv' \
  > /tmp/services.csv
bat /tmp/services.csv
```

**Exercise:** From `services.yaml`, generate a shell script (`/tmp/service-exports.sh`) that exports each service's port as `export <NAME>_PORT=<port>`. Make the variable names uppercase with hyphens replaced by underscores (e.g. `AUTH_SERVICE_PORT`).

---

### Day 6 Checkpoint

- [ ] Created the sample data files (`people.json`, `services.yaml`)
- [ ] Used `select()` to filter JSON and multi-doc YAML by multiple conditions
- [ ] Used `group_by()` + `map()` to aggregate salary data by department
- [ ] Exported `people.json` to a `.csv` file with a header row
- [ ] Edited `services.yaml` in-place with `yq -i` (single service and all services)
- [ ] Converted between YAML and JSON in both directions
- [ ] Piped `yq -o=json` output into `jq` for a combined query
- [ ] Generated a formatted table from YAML using `yq` + `jq` + `column`
- [ ] Generated shell `export` lines from YAML data

> For Kubernetes-specific exercises, continue with [`k8s-exercises.md`](./k8s-exercises.md).

---

### jq Quick Reference

| Filter | What it does |
|--------|-------------|
| `.` | Identity — pass through unchanged |
| `.field` | Extract object field |
| `.[]` | Iterate array or object values |
| `.[n]` | Array index (supports negative) |
| `.[a:b]` | Array slice |
| `select(cond)` | Pass through only if condition is true |
| `map(f)` | Apply filter to every element, collect into array |
| `sort_by(.k)` | Sort array by key |
| `group_by(.k)` | Split array into groups by key |
| `unique` / `unique_by(.k)` | Deduplicate |
| `min_by(.k)` / `max_by(.k)` | Min/max element |
| `add` | Sum array of numbers (or concat strings/arrays) |
| `reduce .[] as $x (init; expr)` | Fold/accumulate |
| `del(.k)` | Remove a field |
| `. + {k: v}` | Add/overwrite a field |
| `@csv` / `@tsv` | Encode array as CSV/TSV row |
| `@base64` / `@uri` | Encode a string |
| `test("regex")` | Regex match — returns bool |

### jq Flags Quick Reference

| Flag | Purpose |
|------|---------|
| `-r` | Raw output — strip JSON string quotes |
| `-c` | Compact — one value per line, no whitespace |
| `-s` | Slurp — read all inputs into a single array |
| `-R` | Raw input — read lines as strings |
| `--arg name val` | Pass shell string as `$name` |
| `--argjson name val` | Pass JSON value as `$name` |
| `-e` | Exit non-zero if output is `null` or `false` |

### yq Quick Reference

| Command | What it does |
|---------|-------------|
| `yq '.' file.yaml` | Pretty-print YAML |
| `yq '.field' file.yaml` | Extract field |
| `yq -o=json '.' file.yaml` | YAML → JSON |
| `yq -P '.' file.json` | JSON → pretty YAML |
| `yq -i '.field = val' file.yaml` | In-place edit |
| `yq 'del(.field)' file.yaml` | Delete field (stdout) |
| `yq -i 'del(.field)' file.yaml` | Delete field in-place |
| `yq 'select(.k == v)' file.yaml` | Filter (multi-doc aware) |
| `yq 'select(document_index == n)' file.yaml` | Pick nth document |
| `yq '. *= load("b.yaml")' a.yaml` | Merge b into a |
| `yq '[.]' multi.yaml` | Collect all docs into array |
| `yq -I=0` | Compact output (no indent) |
