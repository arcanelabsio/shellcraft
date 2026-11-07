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

# Modern tools get their own names; standard commands (ls, cat, grep, find,
# top, diff) are left alone so pasted commands and muscle memory still work.
alias ll="eza -la --icons --group-directories-first"
alias lt="eza -la --icons --tree --level=2"
alias la="eza -a --icons --group-directories-first"
alias reload="source ~/.zshrc"
alias cls="clear"

mkcd() { mkdir -p "$1" && cd "$1"; }

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

__PROFILE_SNIPPETS__

if [[ -f "$SHELLCRAFT_HOME/local.zsh" ]]; then
    source "$SHELLCRAFT_HOME/local.zsh"
fi

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
