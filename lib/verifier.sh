#!/usr/bin/env bash

DOCTOR_MISSING_FORMULAS=()
DOCTOR_PATH_FORMULAS=()

verify_cmd() {
	local name="$1"
	local cmd="${2:-$1}"

	if command -v "$cmd" >/dev/null 2>&1; then
		success "$name available"
	else
		fail "$name missing from PATH"
	fi
}

verify_formula_access() {
	local formula="$1"
	local cmd="$2"

	if command -v "$cmd" >/dev/null 2>&1; then
		success "$formula available"
		return 0
	fi

	if brew_available && formula_installed "$formula"; then
		DOCTOR_PATH_FORMULAS+=("$formula")
		fail "$formula installed but missing from PATH"
	else
		DOCTOR_MISSING_FORMULAS+=("$formula")
		fail "$formula not installed"
	fi
}

warn_if_missing() {
	local description="$1"
	local command_string="$2"

	if eval "$command_string" >/dev/null 2>&1; then
		success "$description"
	else
		warn "$description"
	fi
}

run_doctor() {
	local formula cmd user_shell

	DOCTOR_MISSING_FORMULAS=()
	DOCTOR_PATH_FORMULAS=()

	section "Doctor"

	if brew_available; then
		success "Homebrew available"
	else
		fail "Homebrew not available"
	fi

	for formula in "${SELECTED_FORMULAS[@]}"; do
		if is_local_formula "$formula"; then
			# Local formulas may not ship a command named after them (cocoapods -> pod).
			if brew_available && formula_installed "$formula"; then
				success "$formula installed (local.Brewfile)"
			else
				DOCTOR_MISSING_FORMULAS+=("$formula")
				fail "$formula not installed (local.Brewfile)"
			fi
			continue
		fi
		cmd="$(formula_cmd "$formula")"
		verify_formula_access "$formula" "$cmd"
	done

	warn_if_missing "managed zprofile installed" "[[ -f \"$MANAGED_ZPROFILE\" ]]"
	warn_if_missing "managed zshrc installed" "[[ -f \"$MANAGED_ZSHRC\" ]]"
	warn_if_missing "managed gitconfig installed" "[[ -f \"$MANAGED_GITCONFIG\" ]]"
	warn_if_missing "managed tmux config installed" "[[ -f \"$MANAGED_TMUX_CONF\" ]]"
	warn_if_missing "git user.name configured" "git config --global user.name"
	warn_if_missing "git user.email configured" "git config --global user.email"

	user_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
	if [[ "$user_shell" == *zsh ]]; then
		success "default shell is zsh"
	else
		warn "default shell is not zsh"
	fi
}
