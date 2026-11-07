#!/usr/bin/env bats

load test_helper

setup() {
	setup_test_env
	mkdir -p "$HOME/.config/shellcraft"
	cat >"$HOME/.config/shellcraft/local.Brewfile" <<'EOF'
# per-machine packages
brew "ffmpeg"
brew "cocoapods"
cask "android-platform-tools"
tap "example/tools"
EOF
	cp "$HOME/.config/shellcraft/local.Brewfile" "$BATS_TEST_TMPDIR/local.Brewfile.before"
}

@test "plan lists local.Brewfile formulas and reports skipped casks and taps" {
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --profile core

	[ "$status" -eq 0 ]
	[[ "$output" == *"Formulas from local.Brewfile"* ]]
	[[ "$output" == *"ffmpeg"* ]]
	[[ "$output" == *"cocoapods"* ]]
	[[ "$output" == *"2 cask/tap/mas/vscode line(s) skipped"* ]]
	[[ "$(cat "$HOME/.brew-state")" != *"ffmpeg"* ]]
}

@test "apply installs local.Brewfile formulas and never rewrites the file" {
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --apply --profile core

	[ "$status" -eq 0 ]
	assert_file_contains "$HOME/.brew-state" "ffmpeg"
	assert_file_contains "$HOME/.brew-state" "cocoapods"
	[[ "$(cat "$HOME/.brew-state")" != *"android-platform-tools"* ]]
	cmp -s "$HOME/.config/shellcraft/local.Brewfile" "$BATS_TEST_TMPDIR/local.Brewfile.before"
}

@test "doctor accepts local formulas whose command differs from the formula name" {
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --apply --profile core
	[ "$status" -eq 0 ]

	# The brew stub installs a 'cocoapods' binary, not 'pod'; doctor must check
	# the formula is installed rather than look for a matching command.
	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --doctor --profile core
	[[ "$output" == *"cocoapods installed (local.Brewfile)"* ]]
	[[ "$output" != *"cocoapods installed but missing from PATH"* ]]
}

@test "no local.Brewfile means no local section in the plan" {
	rm "$HOME/.config/shellcraft/local.Brewfile"

	run bash "$BATS_TEST_DIRNAME/../setup-my-mac.sh" --profile core

	[ "$status" -eq 0 ]
	[[ "$output" != *"local.Brewfile"* ]]
}
