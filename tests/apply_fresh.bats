#!/usr/bin/env bats

load test_helper

setup() {
	setup_test_env
}

@test "apply creates managed includes and selected profile state on a fresh home" {
	export SHELLCRAFT_TEST_BREW_OUTDATED="fzf"

	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --apply --profile core --profile maintainer

	[ "$status" -eq 0 ]
	[ -f "$HOME/.config/shellcraft/zshrc.zsh" ]
	[ -f "$HOME/.config/shellcraft/gitconfig" ]
	[ -f "$HOME/.config/shellcraft/state.env" ]
	[ -f "$HOME/.config/shellcraft/local.zsh" ]
	assert_file_contains "$HOME/.zshrc" "$HOME/.config/shellcraft/zshrc.zsh"
	assert_file_contains "$HOME/.gitconfig" "path = ~/.config/shellcraft/gitconfig"
	assert_file_contains "$HOME/.tmux.conf" "source-file ~/.config/shellcraft/tmux.conf"
	assert_file_contains "$HOME/.config/shellcraft/state.env" 'SHELLCRAFT_PROFILES="core,maintainer"'
	assert_file_contains "$HOME/.config/shellcraft/zshrc.zsh" "zsh-autosuggestions"
	[[ "$(cat "$HOME/.config/shellcraft/zshrc.zsh")" != *"kubectl"* ]]
	[[ "$(cat "$HOME/.config/shellcraft/zshrc.zsh")" != *"docker"* ]]
	assert_file_contains "$HOME/.brew-state" "gh"
	assert_file_contains "$HOME/.brew-state" "shellcheck"
	assert_file_contains "$HOME/.brew-state" "markdownlint-cli"
}

@test "managed zshrc leaves standard commands unaliased and initialises each tool once" {
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --apply --profile core --profile ai
	[ "$status" -eq 0 ]

	run zsh -f -c 'source ~/.zshrc; for a in ls cat grep find top diff pip; do alias "$a"; done'
	[ "$status" -ne 0 ] # alias returns non-zero for every undefined name
	[ -z "$output" ]

	local zshrc="$HOME/.config/shellcraft/zshrc.zsh"
	[[ "$(cat "$zshrc")" != *".fzf.zsh"* ]]
	! grep -Eq '^ +z$' "$zshrc" || false
	assert_file_contains "$zshrc" 'eval "$(zoxide init zsh)"'
	[ ! -e "$HOME/.fzf.zsh" ]
}

@test "managed zshrc provides git fuzzy helpers and deduplicates PATH" {
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --apply --profile core
	[ "$status" -eq 0 ]

	run zsh -f -c 'PATH="/usr/bin:/bin:/usr/bin:/bin"; source ~/.zshrc
		for f in fgb fgl fgs fga fgd extract mkcd; do (( ${+functions[$f]} )) || echo "missing $f"; done
		print -r -- "$PATH"'
	[ "$status" -eq 0 ]
	[ "$output" = "/usr/bin:/bin" ]
}

@test "profile-aware zsh config only enables backend and container plugins when selected" {
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --apply --profile core --profile backend --profile containers

	[ "$status" -eq 0 ]
	assert_file_contains "$HOME/.config/shellcraft/zshrc.zsh" "kubectl"
	assert_file_contains "$HOME/.config/shellcraft/zshrc.zsh" "docker"
	assert_file_contains "$HOME/.config/shellcraft/zshrc.zsh" 'alias dco="docker compose"'
}
