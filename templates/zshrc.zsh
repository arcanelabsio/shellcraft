# Shellcraft managed zshrc
export SHELLCRAFT_HOME="$HOME/.config/shellcraft"

# An existing ~/.zshrc may already load Oh My Zsh before this block runs.
# Loading it again resets the user's plugins and re-runs p10k's instant
# prompt mid-startup, so only load it when it isn't loaded yet.
if (( ! ${+functions[omz]} )); then
    export ZSH="$HOME/.oh-my-zsh"
    ZSH_THEME="powerlevel10k/powerlevel10k"

    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
      source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi

    plugins=(
__PLUGINS__
    )

    if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
        source "$ZSH/oh-my-zsh.sh"
    fi
fi

HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY
setopt HIST_FIND_NO_DUPS
setopt HIST_EXPIRE_DUPS_FIRST
setopt EXTENDED_HISTORY

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_CTRL_R_OPTS="
  --preview 'echo {}'
  --preview-window up:3:wrap
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --header 'CTRL-Y to copy | ENTER to run'"
export FZF_CTRL_T_OPTS="
  --preview 'bat --style=numbers --color=always --line-range :300 {} 2>/dev/null || cat {}'"

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
bindkey '^ ' autosuggest-accept # Ctrl+Space accepts the suggestion
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)

# Modern tools get their own names; standard commands (ls, cat, grep, find,
# top, diff) are left alone so pasted commands and muscle memory still work.
alias ll="eza -la --icons --group-directories-first"
alias lt="eza -la --icons --tree --level=2"
alias la="eza -a --icons --group-directories-first"
alias reload="source ~/.zshrc"
alias cls="clear"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias path='print -l $path'
alias ports="lsof -i -P -n | grep LISTEN"
alias h="history | tail -30"
alias brewup="brew update && brew upgrade && brew cleanup"

mkcd() { mkdir -p "$1" && cd "$1"; }

extract() {
    if [[ ! -f "$1" ]]; then
        echo "'$1' is not a valid file"
        return 1
    fi
    case "$1" in
        *.tar.bz2 | *.tbz2) tar xjf "$1" ;;
        *.tar.gz | *.tgz) tar xzf "$1" ;;
        *.tar) tar xf "$1" ;;
        *.bz2) bunzip2 "$1" ;;
        *.gz) gunzip "$1" ;;
        *.zip) unzip "$1" ;;
        *.Z) uncompress "$1" ;;
        *.7z) 7z x "$1" ;;
        *) echo "'$1' cannot be extracted"; return 1 ;;
    esac
}

# Fuzzy git helpers (fzf + delta)
fgb() { # switch branch, newest first
    local branch
    branch=$(git branch --all --sort=-committerdate --format='%(refname:short)' |
        fzf --preview 'git log --oneline --graph --color -15 {}' --header 'Switch branch') || return
    git checkout "${branch#origin/}"
}
fgl() { # browse log, copy selected hash
    local hash
    hash=$(git log --oneline --graph --all --decorate --color |
        fzf --ansi --preview 'git show --stat --color $(echo {} | grep -o "[a-f0-9]\{7,\}" | head -1)' \
            --header 'Browse commits (ENTER copies hash)' |
        grep -o "[a-f0-9]\{7,\}" | head -1)
    [[ -n "$hash" ]] && echo -n "$hash" | pbcopy && echo "Copied: $hash"
}
fgs() { # browse stashes
    git stash list | fzf --preview 'git stash show -p $(echo {} | cut -d: -f1) | delta' --header 'Browse stashes'
}
fga() { # stage files interactively (TAB to multi-select)
    local files
    files=$(git status -s | fzf --multi --preview 'git diff --color {2}' --header 'Stage files' | awk '{print $2}')
    [[ -n "$files" ]] && echo "$files" | xargs git add && git status -sb
}
fgd() { # browse unstaged changes
    git diff --name-only | fzf --preview 'git diff --color {} | delta' --header 'Browse changes'
}

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

__PROFILE_SNIPPETS__

if [[ -f "$SHELLCRAFT_HOME/local.zsh" ]]; then
    source "$SHELLCRAFT_HOME/local.zsh"
fi

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Drop duplicate PATH entries added by installers or /etc/paths.d.
typeset -U path PATH
