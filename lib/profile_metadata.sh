#!/usr/bin/env bash

profile_exists() {
	case "$1" in
	core | backend | ai | maintainer | containers | local-ai) return 0 ;;
	*) return 1 ;;
	esac
}

expand_profile() {
	case "$1" in
	all)
		printf '%s\n' core backend ai maintainer containers local-ai
		;;
	*)
		printf '%s\n' "$1"
		;;
	esac
}

formula_cmd() {
	case "$1" in
	ripgrep) echo "rg" ;;
	git-delta) echo "delta" ;;
	neovim) echo "nvim" ;;
	gnu-sed) echo "gsed" ;;
	kubernetes-cli) echo "kubectl" ;;
	kubectx) echo "kubectx" ;;
	bats-core) echo "bats" ;;
	markdownlint-cli) echo "markdownlint" ;;
	go-task) echo "task" ;;
	tlrc) echo "tldr" ;;
	*) echo "$1" ;;
	esac
}

profile_plugins() {
	case "$1" in
	core)
		printf '%s\n' git z fzf zsh-autosuggestions zsh-syntax-highlighting
		;;
	backend)
		printf '%s\n' kubectl
		;;
	containers)
		printf '%s\n' docker
		;;
	esac
}

profile_snippets() {
	case "$1" in
	backend)
		cat <<'EOF'
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi
alias k="kubectl"
alias kctx="kubectx"
EOF
		;;
	ai)
		cat <<'EOF'
alias py="uv run python"
alias pip="uv pip"
EOF
		;;
	containers)
		cat <<'EOF'
alias dco="docker compose"
EOF
		;;
	esac
}

read_profile_formulas() {
	local profile="$1"
	local brewfile="$SCRIPT_DIR/profiles/${profile}.Brewfile"
	local line formula

	if [[ ! -f "$brewfile" ]]; then
		return 1
	fi

	while IFS= read -r line || [[ -n "$line" ]]; do
		case "$line" in
		brew\ \"*)
			formula="${line#brew \"}"
			formula="${formula%%\"*}"
			printf '%s\n' "$formula"
			;;
		esac
	done <"$brewfile"
}
