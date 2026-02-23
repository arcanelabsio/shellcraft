#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  Mac Developer CLI Power Setup — Bulletproof Edition             ║
# ║  Run anytime — installs on first run, upgrades on repeat runs.   ║
# ║  Free tools only. No fluff. No ads. No prompts.                  ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Usage:
#   chmod +x setup-my-mac.sh
#   ./setup-my-mac.sh          # run from anywhere — script cds to $HOME internally
#
# Features:
#   • Fully unattended — no prompts, auto-approves everything
#   • Verification after every stage with pass/fail reporting
#   • Troubleshooting hints on any failure
#   • PATH handling for Homebrew (Intel + Apple Silicon)
#   • Backs up existing configs before overwriting
#   • Idempotent — safe to re-run
#   • Final summary report with health check
#

# ── Strict mode ─────────────────────────────────────────────────────
set -uo pipefail
# NOTE: We do NOT use `set -e` because we handle errors manually
# with verify checks after each step.

# ── Colors & Formatting ────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Logging ─────────────────────────────────────────────────────────
LOG_FILE="$HOME/.mac-dev-setup.log"
FAILURE_LOG=()
WARNING_LOG=()
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

log()     { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"; }
info()    { echo -e "  ${BLUE}▸${NC} $1"; log "INFO: $1"; }
success() { echo -e "  ${GREEN}✔${NC} $1"; log "OK: $1"; ((SUCCESS_COUNT++)); }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; log "WARN: $1"; WARNING_LOG+=("$1"); }
fail()    { echo -e "  ${RED}✘${NC} $1"; log "FAIL: $1"; ((FAIL_COUNT++)); FAILURE_LOG+=("$1"); }
skip()    { echo -e "  ${DIM}⊘${NC} $1 ${DIM}(already done)${NC}"; log "SKIP: $1"; ((SKIP_COUNT++)); }
section() {
    echo ""
    echo -e "${CYAN}${BOLD}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│  $1$(printf '%*s' $((55 - ${#1})) '')│${NC}"
    echo -e "${CYAN}${BOLD}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    log "═══ $1 ═══"
}
troubleshoot() {
    echo -e "    ${MAGENTA}💡 Troubleshoot:${NC} $1"
    log "TROUBLESHOOT: $1"
}

# ── Verify helper ───────────────────────────────────────────────────
# Usage: verify "description" "command to test" "troubleshoot hint"
verify() {
    local desc="$1"
    local cmd="$2"
    local hint="${3:-No additional troubleshooting available.}"

    if eval "$cmd" &>/dev/null; then
        success "$desc"
        return 0
    else
        fail "$desc"
        troubleshoot "$hint"
        return 1
    fi
}

# Verify a command exists and print its version
verify_cmd() {
    local name="$1"
    local cmd="${2:-$1}"
    local hint="${3:-Try: brew install $name}"

    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>/dev/null | head -1 || echo "installed")
        success "$name → ${DIM}$version${NC}"
        return 0
    else
        fail "$name not found in PATH"
        troubleshoot "$hint"
        return 1
    fi
}

# ── Sudo keep-alive ────────────────────────────────────────────────
# Ask for sudo once upfront, then keep it alive for the entire script.
acquire_sudo() {
    echo -e "\n${BOLD}This script needs sudo for Xcode CLI tools and some installs.${NC}"
    echo -e "${DIM}You'll be prompted once — sudo stays active for the rest.${NC}\n"

    # Prompt for password
    if ! sudo -v; then
        echo -e "${RED}Failed to acquire sudo. Exiting.${NC}"
        exit 1
    fi

    # Keep sudo alive in the background
    while true; do
        sudo -n true
        sleep 50
        kill -0 "$$" || exit
    done 2>/dev/null &
    SUDO_KEEPER_PID=$!
    log "Sudo keep-alive started (PID: $SUDO_KEEPER_PID)"
}

# Cleanup on exit
cleanup() {
    if [[ -n "${SUDO_KEEPER_PID:-}" ]]; then
        kill "$SUDO_KEEPER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ── Always run from $HOME ────────────────────────────────────────────
# The script may be stored anywhere (e.g. ~/workspace/setup-my-workstation).
# All writes target $HOME or absolute paths, so we anchor CWD to $HOME
# early so that any subprocess that inherits CWD behaves predictably.
cd "$HOME" || { echo "ERROR: Cannot cd to \$HOME ($HOME). Aborting." >&2; exit 1; }

# ── Constants ───────────────────────────────────────────────────────
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# ════════════════════════════════════════════════════════════════════
# PREFLIGHT
# ════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       Mac Developer CLI Power Setup — Bulletproof Edition   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Log file: ${DIM}$LOG_FILE${NC}"
echo ""

# Start fresh log
echo "=== Mac Dev Setup — $(date) ===" > "$LOG_FILE"

# ── OS check ────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    fail "This script is for macOS only. Detected: $(uname)"
    exit 1
fi

# Detect architecture
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
    info "Detected Apple Silicon (arm64)"
else
    BREW_PREFIX="/usr/local"
    info "Detected Intel (x86_64)"
fi

# Acquire sudo
acquire_sudo

# ════════════════════════════════════════════════════════════════════
section "1/7 — Xcode Command Line Tools"
# ════════════════════════════════════════════════════════════════════

if xcode-select -p &>/dev/null; then
    skip "Xcode CLI Tools already installed"
    verify "Xcode CLI Tools path" "xcode-select -p" \
        "Run: sudo xcode-select --reset"
else
    info "Installing Xcode Command Line Tools (this may take a few minutes)..."

    # Trigger install via softwareupdate (no GUI prompt)
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    PROD=$(softwareupdate -l 2>/dev/null | grep -B 1 "Command Line Tools" | grep -o 'Command Line Tools.*' | head -1)

    if [[ -n "$PROD" ]]; then
        sudo softwareupdate -i "$PROD" --verbose 2>&1 | tail -5
        rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    else
        # Fallback: trigger the GUI install and wait
        xcode-select --install 2>/dev/null || true
        info "Waiting for Xcode CLI Tools installation to complete..."
        until xcode-select -p &>/dev/null; do
            sleep 5
        done
        rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    fi

    verify "Xcode CLI Tools installed" "xcode-select -p" \
        "Run manually: xcode-select --install"
fi

# Accept Xcode license silently
sudo xcodebuild -license accept 2>/dev/null || true

echo ""
echo -e "  ${DIM}── Verification ──${NC}"
verify "git available (from Xcode)" "command -v git" \
    "Xcode CLI tools may not have installed correctly. Run: sudo xcode-select --reset"

# ════════════════════════════════════════════════════════════════════
section "2/7 — Homebrew"
# ════════════════════════════════════════════════════════════════════

export NONINTERACTIVE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

if command -v brew &>/dev/null; then
    skip "Homebrew already installed"
else
    info "Installing Homebrew (non-interactive)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
fi

# ── Ensure brew is in PATH for this session AND future shells ──────
setup_brew_path() {
    # Add to current session
    if [[ -f "$BREW_PREFIX/bin/brew" ]]; then
        eval "$("$BREW_PREFIX/bin/brew" shellenv)"
    fi

    # Ensure it's in .zprofile for login shells
    local ZPROFILE="$HOME/.zprofile"
    local BREW_SHELLENV="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""

    if [[ ! -f "$ZPROFILE" ]] || ! grep -q "brew shellenv" "$ZPROFILE" 2>/dev/null; then
        echo "" >> "$ZPROFILE"
        echo "# Homebrew" >> "$ZPROFILE"
        echo "$BREW_SHELLENV" >> "$ZPROFILE"
        info "Added Homebrew to ~/.zprofile"
    fi
}

setup_brew_path

echo ""
echo -e "  ${DIM}── Verification ──${NC}"
verify "brew command available" "command -v brew" \
    "Homebrew binary not found. Check $BREW_PREFIX/bin/brew exists. For Apple Silicon, ensure /opt/homebrew/bin is in PATH."
verify "brew prefix correct ($BREW_PREFIX)" "[[ \$(brew --prefix) == '$BREW_PREFIX' ]]" \
    "Homebrew installed in unexpected location. Expected $BREW_PREFIX."

if command -v brew &>/dev/null; then
    BREW_VERSION=$(brew --version | head -1)
    info "Homebrew version: $BREW_VERSION"
    info "Updating Homebrew..."
    brew update --quiet 2>/dev/null
fi

# ════════════════════════════════════════════════════════════════════
section "3/7 — CLI Tools"
# ════════════════════════════════════════════════════════════════════

# bash 3.2 compatible lookup (macOS ships bash 3.2; declare -A requires 4+)
get_tool_cmd() {
    case "$1" in
        ripgrep)   echo "rg" ;;
        git-delta) echo "delta" ;;
        neovim)    echo "nvim" ;;
        gnu-sed)   echo "gsed" ;;
        *)         echo "$1" ;;
    esac
}

BREW_PACKAGES=(git tmux fzf ripgrep fd bat eza zoxide tldr jq yq lazygit git-delta htop git-absorb neovim wget tree gnu-sed)

for pkg in "${BREW_PACKAGES[@]}"; do
    if brew list "$pkg" &>/dev/null; then
        skip "$pkg"
    else
        info "Installing $pkg..."
        if brew install "$pkg" --quiet 2>>"$LOG_FILE"; then
            success "$pkg installed"
        else
            fail "$pkg installation failed"
            troubleshoot "Try manually: brew install $pkg  |  Check: brew doctor"
        fi
    fi
done

# Upgrade any outdated packages from our list in one batch
info "Checking for outdated packages..."
BREW_OUTDATED=$(brew outdated --quiet 2>/dev/null || true)
OUTDATED_LIST=()
for pkg in "${BREW_PACKAGES[@]}"; do
    if echo "$BREW_OUTDATED" | /usr/bin/grep -q "^${pkg}$"; then
        OUTDATED_LIST+=("$pkg")
    fi
done
if [[ ${#OUTDATED_LIST[@]} -gt 0 ]]; then
    info "Upgrading ${#OUTDATED_LIST[@]} package(s): ${OUTDATED_LIST[*]}"
    if brew upgrade "${OUTDATED_LIST[@]}" --quiet 2>>"$LOG_FILE"; then
        success "Packages upgraded"
    else
        warn "Some packages failed to upgrade — check $LOG_FILE"
    fi
else
    info "All CLI tools already at latest version"
fi

# fzf key bindings (auto-approve)
if [[ ! -f "$HOME/.fzf.zsh" ]]; then
    info "Setting up fzf key bindings..."
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish </dev/null
fi

echo ""
echo -e "  ${DIM}── Verification ──${NC}"

for pkg in "${BREW_PACKAGES[@]}"; do
    cmd=$(get_tool_cmd "$pkg")
    verify_cmd "$pkg ($cmd)" "$cmd" "Try: brew install $pkg && brew link $pkg"
done

verify "fzf key bindings" "[[ -f ~/.fzf.zsh ]]" \
    "Run: \$(brew --prefix)/opt/fzf/install --all"

# ── Verify tools are on PATH ──────────────────────────────────────
echo ""
echo -e "  ${DIM}── PATH Check ──${NC}"
verify "Homebrew bin in PATH" "echo \$PATH | grep -q '$BREW_PREFIX/bin'" \
    "Add to ~/.zprofile: eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
verify "Homebrew sbin in PATH" "echo \$PATH | grep -q '$BREW_PREFIX/sbin'" \
    "Add to ~/.zprofile: eval \"\$($BREW_PREFIX/bin/brew shellenv)\""

# ════════════════════════════════════════════════════════════════════
section "4/7 — Oh My Zsh"
# ════════════════════════════════════════════════════════════════════

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    skip "Oh My Zsh already installed"
    info "Updating Oh My Zsh..."
    if git -C "$HOME/.oh-my-zsh" pull --quiet 2>>"$LOG_FILE"; then
        success "Oh My Zsh updated"
    else
        warn "Oh My Zsh update failed — check $LOG_FILE"
    fi
else
    info "Installing Oh My Zsh (non-interactive)..."
    RUNZSH=no KEEP_ZSHRC=yes CHSH=no \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended </dev/null
fi

echo ""
echo -e "  ${DIM}── Verification ──${NC}"
verify "Oh My Zsh directory exists" "[[ -d $HOME/.oh-my-zsh ]]" \
    "Try: rm -rf ~/.oh-my-zsh and re-run this script"
verify "Oh My Zsh oh-my-zsh.sh present" "[[ -f $HOME/.oh-my-zsh/oh-my-zsh.sh ]]" \
    "Installation may be corrupt. rm -rf ~/.oh-my-zsh and re-run."

# ── Set Zsh as default shell (no prompt) ───────────────────────────
CURRENT_SHELL=$(dscl . -read /Users/"$(whoami)" UserShell 2>/dev/null | awk '{print $2}')
ZSH_PATH=$(which zsh)
if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
    info "Setting zsh as default shell..."
    # Add to /etc/shells if missing
    if ! grep -q "$ZSH_PATH" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
    sudo chsh -s "$ZSH_PATH" "$(whoami)"
    verify "Default shell set to zsh" "[[ \$(dscl . -read /Users/\$(whoami) UserShell | awk '{print \$2}') == '$ZSH_PATH' ]]" \
        "Run manually: chsh -s $(which zsh)"
else
    skip "Default shell is already zsh"
fi

# ════════════════════════════════════════════════════════════════════
section "5/7 — Zsh Plugins & Theme"
# ════════════════════════════════════════════════════════════════════

# ── Powerlevel10k ───────────────────────────────────────────────────
if [[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    info "Updating Powerlevel10k..."
    if git -C "$ZSH_CUSTOM/themes/powerlevel10k" pull --quiet 2>>"$LOG_FILE"; then
        success "Powerlevel10k updated"
    else
        warn "Powerlevel10k update failed — check $LOG_FILE"
    fi
else
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM/themes/powerlevel10k" 2>>"$LOG_FILE"
    success "Powerlevel10k installed"
fi

# ── Nerd Font (Powerlevel10k needs this) ────────────────────────────
if brew list --cask font-meslo-lg-nerd-font &>/dev/null 2>&1; then
    info "Upgrading MesloLGS Nerd Font..."
    brew upgrade --cask font-meslo-lg-nerd-font --quiet 2>>"$LOG_FILE" \
        && success "MesloLGS Nerd Font upgraded" \
        || skip "MesloLGS Nerd Font (already latest)"
else
    info "Installing MesloLGS Nerd Font (required for Powerlevel10k icons)..."
    brew install --cask font-meslo-lg-nerd-font --quiet 2>>"$LOG_FILE" \
        && success "MesloLGS Nerd Font installed" \
        || warn "Font install failed — install manually: brew install --cask font-meslo-lg-nerd-font"
fi

# ── zsh-autosuggestions ─────────────────────────────────────────────
if [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    info "Updating zsh-autosuggestions..."
    if git -C "$ZSH_CUSTOM/plugins/zsh-autosuggestions" pull --quiet 2>>"$LOG_FILE"; then
        success "zsh-autosuggestions updated"
    else
        warn "zsh-autosuggestions update failed — check $LOG_FILE"
    fi
else
    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>>"$LOG_FILE"
    success "zsh-autosuggestions installed"
fi

# ── zsh-syntax-highlighting ─────────────────────────────────────────
if [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    info "Updating zsh-syntax-highlighting..."
    if git -C "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" pull --quiet 2>>"$LOG_FILE"; then
        success "zsh-syntax-highlighting updated"
    else
        warn "zsh-syntax-highlighting update failed — check $LOG_FILE"
    fi
else
    info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>>"$LOG_FILE"
    success "zsh-syntax-highlighting installed"
fi

echo ""
echo -e "  ${DIM}── Verification ──${NC}"
verify "Powerlevel10k theme" "[[ -f $ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme ]]" \
    "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k"
verify "zsh-autosuggestions plugin" "[[ -f $ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]" \
    "git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions"
verify "zsh-syntax-highlighting plugin" "[[ -f $ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]" \
    "git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
verify "MesloLGS Nerd Font available" "fc-list 2>/dev/null | grep -qi meslo || system_profiler SPFontsDataType 2>/dev/null | grep -qi meslo" \
    "Install manually: brew install --cask font-meslo-lg-nerd-font  |  Then set your terminal font to 'MesloLGS NF'"

# ════════════════════════════════════════════════════════════════════
section "6/7 — Generating Config Files"
# ════════════════════════════════════════════════════════════════════

# ── Backup helper ──────────────────────────────────────────────────
backup_if_exists() {
    local file="$1"
    if [[ -f "$file" && ! -L "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/"
        info "Backed up $(basename "$file") → $BACKUP_DIR/"
    fi
}

# ─────────────────────────────────────────────────────────────────
# .zshrc
# ─────────────────────────────────────────────────────────────────
info "Generating .zshrc..."
backup_if_exists "$HOME/.zshrc"
cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# ╔══════════════════════════════════════════════════════════════════╗
# ║  .zshrc                                                          ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Powerlevel10k instant prompt (keep at very top) ────────────────
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── Homebrew (must be before Oh My Zsh) ────────────────────────────
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# ── Oh My Zsh ───────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    z
    fzf
    docker
    kubectl
    zsh-autosuggestions
    zsh-syntax-highlighting   # must be last plugin
)

source "$ZSH/oh-my-zsh.sh"

# ── History ─────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY            # share across sessions
setopt HIST_IGNORE_ALL_DUPS     # no duplicate entries
setopt HIST_IGNORE_SPACE        # space-prefix = secret command
setopt HIST_REDUCE_BLANKS       # clean up whitespace
setopt INC_APPEND_HISTORY       # write immediately, not on exit
setopt HIST_FIND_NO_DUPS        # no dupes in Ctrl+R search
setopt HIST_EXPIRE_DUPS_FIRST   # expire dupes before unique cmds
setopt EXTENDED_HISTORY          # save timestamps

# ── fzf ─────────────────────────────────────────────────────────────
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_CTRL_R_OPTS="
  --preview 'echo {}'
  --preview-window up:3:wrap
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --header 'CTRL-Y to copy | ENTER to run'"
export FZF_CTRL_T_OPTS="
  --preview 'bat --style=numbers --color=always --line-range :300 {} 2>/dev/null || cat {}'
  --header 'CTRL-T: fuzzy file finder'"

# ── Autosuggestions ─────────────────────────────────────────────────
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#888888"
bindkey '^ ' autosuggest-accept   # Ctrl+Space to accept

# ── Syntax highlighting ────────────────────────────────────────────
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)

# ── Tool replacements ──────────────────────────────────────────────
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first"
alias lt="eza -la --icons --tree --level=2"
alias la="eza -a --icons --group-directories-first"
alias cat="bat --paging=never"
alias grep="rg"
alias find="fd"
alias top="htop"
alias diff="delta"

# ── zoxide (smarter cd) ────────────────────────────────────────────
eval "$(zoxide init zsh)"

# ── Git delta as pager ──────────────────────────────────────────────
export GIT_PAGER="delta"

# ── Git fuzzy helpers ───────────────────────────────────────────────
# Fuzzy branch switch
fgb() {
    local branch
    branch=$(git branch --all --sort=-committerdate --format='%(refname:short)' | \
        fzf --preview 'git log --oneline --graph --color -15 {}' \
            --header 'Switch branch (ENTER to select)') || return
    branch="${branch#origin/}"
    git checkout "$branch"
}

# Fuzzy log browser — copies selected hash
fgl() {
    local hash
    hash=$(git log --oneline --graph --all --decorate --color | \
        fzf --ansi --preview 'git show --stat --color $(echo {} | grep -o "[a-f0-9]\{7,\}" | head -1)' \
            --header 'Browse commits (ENTER to copy hash)' | \
        grep -o "[a-f0-9]\{7,\}" | head -1)
    if [[ -n "$hash" ]]; then
        echo "$hash" | pbcopy
        echo "Copied: $hash"
    fi
}

# Fuzzy stash browser
fgs() {
    git stash list | \
        fzf --preview 'git stash show -p $(echo {} | cut -d: -f1) | delta' \
            --header 'Browse stashes'
}

# Interactive git add (stage individual files)
fga() {
    local files
    files=$(git status -s | \
        fzf --multi --preview 'git diff --color {2}' \
            --header 'Select files to stage (TAB multi-select)' | \
        awk '{print $2}')
    if [[ -n "$files" ]]; then
        echo "$files" | xargs git add
        git status -sb
    fi
}

# Fuzzy git diff browser
fgd() {
    git diff --name-only | \
        fzf --preview 'git diff --color {} | delta' \
            --header 'Browse changes'
}

alias gb="fgb"
alias gl="fgl"
alias gs="fgs"
alias ga="fga"
alias gd="fgd"

# ── Navigation shortcuts ───────────────────────────────────────────
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias cls="clear"
alias ports="lsof -i -P -n | grep LISTEN"
alias myip="curl -s ifconfig.me"
alias reload="source ~/.zshrc && echo '✔ Reloaded!'"
alias path='echo -e ${PATH//:/\\n}'
alias h="history | tail -30"
alias hg="history | rg"
alias brewup="brew update && brew upgrade && brew cleanup"

# Mkdir and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Quick notes
note() { echo "$(date '+%Y-%m-%d %H:%M') — $*" >> ~/notes.md; }

# Extract any archive
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.rar)     unrar x "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.tbz2)    tar xjf "$1" ;;
            *.tgz)     tar xzf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.Z)       uncompress "$1" ;;
            *.7z)      7z x "$1" ;;
            *)         echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# ── Load custom aliases (your shortcuts go here) ───────────────────
[[ -f "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/dotfiles/aliases.zsh" ]] && \
    source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/dotfiles/aliases.zsh"

# ── Powerlevel10k config ───────────────────────────────────────────
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSHRC_EOF
success ".zshrc generated"

# ─────────────────────────────────────────────────────────────────
# .gitconfig
# ─────────────────────────────────────────────────────────────────
info "Generating .gitconfig..."
backup_if_exists "$HOME/.gitconfig"

EXISTING_NAME=$(git config --global user.name 2>/dev/null || echo "")
EXISTING_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

cat > "$HOME/.gitconfig" << GITCONFIG_EOF
[user]
    name = ${EXISTING_NAME:-Your Name}
    email = ${EXISTING_EMAIL:-you@example.com}

[core]
    pager = delta
    editor = vim
    excludesFile = ~/.gitignore_global
    autocrlf = input

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    side-by-side = true
    line-numbers = true
    syntax-theme = Dracula

[merge]
    conflictstyle = zdiff3
    tool = vimdiff

[diff]
    algorithm = histogram
    colorMoved = default

[pull]
    rebase = true

[push]
    autoSetupRemote = true
    default = current

[fetch]
    prune = true

[rerere]
    enabled = true

[init]
    defaultBranch = main

[alias]
    st = status -sb
    co = checkout
    br = branch
    cm = commit -m
    ca = commit --amend --no-edit
    lg = log --oneline --graph --decorate --all -20
    ll = log --pretty=format:'%C(yellow)%h%C(reset) %C(green)%ad%C(reset) | %s %C(red)%d%C(reset) %C(blue)[%an]%C(reset)' --date=short --all
    undo = reset --soft HEAD~1
    wip = !git add -A && git commit -m 'WIP'
    unwip = reset HEAD~1
    recent = branch --sort=-committerdate --format='%(committerdate:relative)  %(refname:short)'
    bl = blame -w -C -C -C
    cleanup = !git branch --merged main | grep -v 'main' | xargs -n 1 git branch -d
    stash-all = stash push --include-untracked
    aliases = config --get-regexp alias
GITCONFIG_EOF
success ".gitconfig generated"

# ─────────────────────────────────────────────────────────────────
# .gitignore_global
# ─────────────────────────────────────────────────────────────────
info "Generating .gitignore_global..."
backup_if_exists "$HOME/.gitignore_global"
cat > "$HOME/.gitignore_global" << 'GITIGNORE_EOF'
# macOS
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes

# Editors
*.swp
*.swo
*~
.idea/
.vscode/settings.json
*.sublime-project
*.sublime-workspace

# Environment
.env
.env.local
.env.*.local

# Node
node_modules/

# Python
__pycache__/
*.pyc
.venv/
GITIGNORE_EOF
success ".gitignore_global generated"

# ─────────────────────────────────────────────────────────────────
# .tmux.conf
# ─────────────────────────────────────────────────────────────────
info "Generating .tmux.conf..."
backup_if_exists "$HOME/.tmux.conf"
cat > "$HOME/.tmux.conf" << 'TMUX_EOF'
# ╔══════════════════════════════════════════════════════════════════╗
# ║  tmux config                                                     ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Prefix: Ctrl+a ─────────────────────────────────────────────────
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# ── General ─────────────────────────────────────────────────────────
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -sg escape-time 0

# ── Splits (in current path) ──────────────────────────────────────
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

# ── Navigate panes (vim keys) ─────────────────────────────────────
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# ── Resize panes ──────────────────────────────────────────────────
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# ── Reload config ─────────────────────────────────────────────────
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# ── Copy mode (vim style + macOS clipboard) ───────────────────────
setw -g mode-keys vi
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"

# ── Status bar ─────────────────────────────────────────────────────
set -g status-position top
set -g status-style "bg=default,fg=white"
set -g status-left "#[bold,fg=cyan] #S "
set -g status-right "#[fg=yellow]%H:%M #[fg=white]│ #[fg=green]%d-%b-%Y "
set -g status-left-length 30
set -g window-status-format " #I:#W "
set -g window-status-current-format "#[bold,fg=cyan] #I:#W "
TMUX_EOF
success ".tmux.conf generated"

# ─────────────────────────────────────────────────────────────────
# aliases.zsh (only if not present — preserves user customizations)
# ─────────────────────────────────────────────────────────────────
if [[ ! -f "$ZSH_CUSTOM/aliases.zsh" ]]; then
    info "Generating aliases.zsh placeholder..."
    cat > "$ZSH_CUSTOM/aliases.zsh" << 'ALIASES_EOF'
# ╔══════════════════════════════════════════════════════════════════╗
# ║  Custom Aliases & Shortcuts                                      ║
# ║  Add your own shortcuts here — auto-loaded by Oh My Zsh          ║
# ╚══════════════════════════════════════════════════════════════════╝

# Example:
# alias proj="cd ~/Projects"
# alias deploy="./scripts/deploy.sh"
ALIASES_EOF
    success "aliases.zsh generated"
else
    skip "aliases.zsh already exists — preserved"
fi

echo ""
echo -e "  ${DIM}── Verification ──${NC}"
verify ".zshrc exists" "[[ -f $HOME/.zshrc ]]" \
    "Re-run this script"
verify ".gitconfig exists" "[[ -f $HOME/.gitconfig ]]" \
    "Re-run this script"
verify ".gitignore_global exists" "[[ -f $HOME/.gitignore_global ]]" \
    "Re-run this script"
verify ".tmux.conf exists" "[[ -f $HOME/.tmux.conf ]]" \
    "Re-run this script"
verify "aliases.zsh in ZSH_CUSTOM" "[[ -f $ZSH_CUSTOM/aliases.zsh ]]" \
    "Create: touch $ZSH_CUSTOM/aliases.zsh"

# ════════════════════════════════════════════════════════════════════
section "7/7 — Final Health Check"
# ════════════════════════════════════════════════════════════════════

echo -e "  ${DIM}── Shell Environment ──${NC}"
verify "Zsh is default shell" "[[ \$(dscl . -read /Users/\$(whoami) UserShell | awk '{print \$2}') == *zsh ]]" \
    "Run: chsh -s \$(which zsh)"
verify "HISTFILE configured" "[[ -n '${HISTFILE:-}' || -f ~/.zsh_history ]]" \
    "Check .zshrc for HISTFILE setting"
verify ".zprofile has Homebrew PATH" "grep -q 'brew shellenv' $HOME/.zprofile 2>/dev/null" \
    "Add to ~/.zprofile: eval \"\$($BREW_PREFIX/bin/brew shellenv)\""

echo ""
echo -e "  ${DIM}── Git Configuration ──${NC}"
verify "git user.name set" "[[ -n \$(git config --global user.name) ]]" \
    "Run: git config --global user.name 'Your Name'"
verify "git user.email set" "[[ -n \$(git config --global user.email) ]]" \
    "Run: git config --global user.email 'you@example.com'"
verify "git delta pager" "[[ \$(git config --global core.pager) == 'delta' ]]" \
    "Run: git config --global core.pager delta"
verify "git rerere enabled" "[[ \$(git config --global rerere.enabled) == 'true' ]]" \
    "Run: git config --global rerere.enabled true"
verify "git pull rebase" "[[ \$(git config --global pull.rebase) == 'true' ]]" \
    "Run: git config --global pull.rebase true"

# ── Backup report ──────────────────────────────────────────────────
if [[ -d "$BACKUP_DIR" ]]; then
    echo ""
    echo -e "  ${DIM}── Backups ──${NC}"
    info "Previous configs backed up to:"
    info "  $BACKUP_DIR"
    ls -1 "$BACKUP_DIR" 2>/dev/null | while read -r f; do
        echo -e "    ${DIM}→ $f${NC}"
    done
fi

# ════════════════════════════════════════════════════════════════════
# FINAL REPORT
# ════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                      SETUP REPORT                           ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║${NC}  ${GREEN}✔ Passed:${NC}  $SUCCESS_COUNT                                             ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  ${DIM}⊘ Skipped:${NC} $SKIP_COUNT  ${DIM}(already installed)${NC}                       ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  ${RED}✘ Failed:${NC}  $FAIL_COUNT                                              ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

if [[ ${#FAILURE_LOG[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}${BOLD}Failed items:${NC}"
    for item in "${FAILURE_LOG[@]}"; do
        echo -e "  ${RED}✘${NC} $item"
    done
fi

if [[ ${#WARNING_LOG[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}${BOLD}Warnings:${NC}"
    for item in "${WARNING_LOG[@]}"; do
        echo -e "  ${YELLOW}⚠${NC} $item"
    done
fi

echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo -e "  ${CYAN}1.${NC} Restart your terminal ${DIM}(or run: source ~/.zshrc)${NC}"
echo -e "  ${CYAN}2.${NC} Run ${BOLD}p10k configure${NC} to set up your prompt theme"
echo -e "  ${CYAN}3.${NC} Set your terminal font to ${BOLD}MesloLGS NF${NC}"
echo -e "  ${CYAN}4.${NC} Update git identity if needed:"
echo -e "     ${DIM}git config --global user.name 'Your Name'${NC}"
echo -e "     ${DIM}git config --global user.email 'you@example.com'${NC}"
echo -e "  ${CYAN}5.${NC} Add custom shortcuts to ${BOLD}~/.oh-my-zsh/custom/aliases.zsh${NC}"
echo ""
echo -e "${BOLD}Key bindings:${NC}"
echo ""
echo -e "  ${GREEN}Ctrl+R${NC}       Fuzzy search command history"
echo -e "  ${GREEN}Ctrl+T${NC}       Fuzzy find files"
echo -e "  ${GREEN}Ctrl+Space${NC}   Accept autosuggestion"
echo -e "  ${GREEN}→${NC}            Accept autosuggestion (alternative)"
echo -e "  ${GREEN}gb${NC}           Fuzzy git branch switch"
echo -e "  ${GREEN}gl${NC}           Fuzzy git log (copies hash)"
echo -e "  ${GREEN}ga${NC}           Fuzzy interactive git add"
echo -e "  ${GREEN}gs${NC}           Fuzzy stash browser"
echo -e "  ${GREEN}gd${NC}           Fuzzy git diff browser"
echo -e "  ${GREEN}lazygit${NC}      Full terminal git UI"
echo ""
echo -e "  ${DIM}Full log: $LOG_FILE${NC}"
echo ""
echo -e "${GREEN}${BOLD}Done! Happy hacking! 🚀${NC}"
