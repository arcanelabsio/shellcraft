#!/usr/bin/env bats

load test_helper

setup() {
	setup_test_env
}

@test "default run is plan mode and does not mutate HOME" {
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh"

	[ "$status" -eq 0 ]
	[[ "$output" == *"Mode: plan"* ]]
	[[ "$output" == *"Profiles: core"* ]]
	[ ! -e "$HOME/.config/shellcraft" ]
	[ ! -e "$HOME/.zshrc" ]
}

@test "apply fails fast when Xcode CLI tools are missing and GUI installs are blocked" {
	export SHELLCRAFT_TEST_XCODE_MISSING=1

	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --apply --profile core

	[ "$status" -eq 1 ]
	[[ "$output" == *"Xcode CLI Tools are missing"* ]]
	[[ "$output" == *"--allow-gui-installs"* ]]
	[ ! -e "$HOME/.config/shellcraft" ]
	[ ! -e "$HOME/.xcode-install-invoked" ]
}

@test "doctor fix installs missing formulas and adopts managed config" {
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --doctor --fix --profile core

	[ "$status" -eq 0 ]
	[ -f "$HOME/.config/shellcraft/zshrc.zsh" ]
	assert_file_contains "$HOME/.brew-state" "yq"
	assert_file_contains "$HOME/.zshrc" "$HOME/.config/shellcraft/zshrc.zsh"
}

@test "plan reports a deprecated formula that conflicts with its replacement" {
	echo "tldr" >>"$HOME/.brew-state"

	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --profile core

	[ "$status" -eq 0 ]
	[[ "$output" == *"Formula conflicts (resolve before apply)"* ]]
	[[ "$output" == *"tldr conflicts with tlrc; run: brew uninstall tldr"* ]]
}

@test "plan has no conflicts section when nothing conflicts" {
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --profile core

	[ "$status" -eq 0 ]
	[[ "$output" != *"Formula conflicts"* ]]
}
