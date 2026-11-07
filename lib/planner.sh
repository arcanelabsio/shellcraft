#!/usr/bin/env bash

# shellcheck disable=SC2034
PLANNER_ERROR=""
SELECTED_PROFILES=()
SELECTED_FORMULAS=()
LOCAL_FORMULAS=()
LOCAL_SKIPPED_LINES=0
SELECTED_PLUGINS=()
SELECTED_SNIPPETS=()
FORMULAS_TO_INSTALL=()
FORMULAS_INSTALLED=()
FORMULAS_TO_UPGRADE=()

array_contains() {
	local needle="$1"
	shift
	local item

	for item in "$@"; do
		if [[ "$item" == "$needle" ]]; then
			return 0
		fi
	done

	return 1
}

append_unique() {
	local value="$1"
	shift
	if array_contains "$value" "$@"; then
		return 1
	fi
	return 0
}

join_by() {
	local delimiter="$1"
	shift
	local first=1
	local value

	for value in "$@"; do
		if [[ $first -eq 1 ]]; then
			printf '%s' "$value"
			first=0
		else
			printf '%s%s' "$delimiter" "$value"
		fi
	done
}

resolve_selected_profiles() {
	local requested=("$@")
	local requested_profile resolved

	PLANNER_ERROR=""
	SELECTED_PROFILES=()

	if [[ ${#requested[@]} -eq 0 ]]; then
		requested=(core)
	fi

	for requested_profile in "${requested[@]}"; do
		if [[ "$requested_profile" != "all" ]] && ! profile_exists "$requested_profile"; then
			PLANNER_ERROR="Unknown profile: $requested_profile"
			return 1
		fi

		for resolved in $(expand_profile "$requested_profile"); do
			if append_unique "$resolved" "${SELECTED_PROFILES[@]}"; then
				SELECTED_PROFILES+=("$resolved")
			fi
		done
	done

	return 0
}

collect_selected_formulas() {
	local profile formula

	SELECTED_FORMULAS=()

	for profile in "${SELECTED_PROFILES[@]}"; do
		while IFS= read -r formula; do
			if [[ -n "$formula" ]] && append_unique "$formula" "${SELECTED_FORMULAS[@]}"; then
				SELECTED_FORMULAS+=("$formula")
			fi
		done <<EOF
$(read_profile_formulas "$profile")
EOF
	done

	collect_local_formulas
}

collect_local_formulas() {
	local brewfile formula

	LOCAL_FORMULAS=()
	LOCAL_SKIPPED_LINES=0
	brewfile="$(local_brewfile_path)"
	[[ -f "$brewfile" ]] || return 0

	while IFS= read -r formula; do
		[[ -n "$formula" ]] || continue
		LOCAL_FORMULAS+=("$formula")
		if append_unique "$formula" "${SELECTED_FORMULAS[@]}"; then
			SELECTED_FORMULAS+=("$formula")
		fi
	done <<EOF
$(read_brewfile_formulas "$brewfile")
EOF

	# Casks and taps are outside Shellcraft's scope (ADR-0003); say so in the plan.
	LOCAL_SKIPPED_LINES="$(grep -Ec '^[[:space:]]*(cask|tap|mas|vscode)[[:space:]]' "$brewfile" || true)"
}

is_local_formula() {
	local formula
	for formula in "${LOCAL_FORMULAS[@]}"; do
		[[ "$formula" == "$1" ]] && return 0
	done
	return 1
}

collect_selected_plugins() {
	local profile plugin

	SELECTED_PLUGINS=()

	for profile in "${SELECTED_PROFILES[@]}"; do
		while IFS= read -r plugin; do
			if [[ -n "$plugin" ]] && append_unique "$plugin" "${SELECTED_PLUGINS[@]}"; then
				SELECTED_PLUGINS+=("$plugin")
			fi
		done <<EOF
$(profile_plugins "$profile")
EOF
	done
}

collect_selected_snippets() {
	local profile snippet

	SELECTED_SNIPPETS=()

	for profile in "${SELECTED_PROFILES[@]}"; do
		snippet="$(profile_snippets "$profile")"
		if [[ -n "$snippet" ]]; then
			SELECTED_SNIPPETS+=("$snippet")
		fi
	done
}

resolve_brew_binary() {
	if command -v brew >/dev/null 2>&1; then
		BREW_BIN="$(command -v brew)"
		return 0
	fi

	if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
		BREW_BIN="$BREW_PREFIX/bin/brew"
		return 0
	fi

	BREW_BIN=""
	return 1
}

brew_available() {
	resolve_brew_binary >/dev/null 2>&1
}

formula_installed() {
	"$BREW_BIN" list --formula "$1" >/dev/null 2>&1
}

formula_outdated() {
	printf '%s\n' "$BREW_OUTDATED_CACHE" | grep -qx "$1"
}

compute_brew_plan() {
	local formula

	FORMULAS_TO_INSTALL=()
	FORMULAS_INSTALLED=()
	FORMULAS_TO_UPGRADE=()

	if ! brew_available; then
		FORMULAS_TO_INSTALL=("${SELECTED_FORMULAS[@]}")
		return 0
	fi

	BREW_OUTDATED_CACHE="$("$BREW_BIN" outdated --quiet 2>/dev/null || true)"

	for formula in "${SELECTED_FORMULAS[@]}"; do
		if formula_installed "$formula"; then
			FORMULAS_INSTALLED+=("$formula")
			if formula_outdated "$formula"; then
				FORMULAS_TO_UPGRADE+=("$formula")
			fi
		else
			FORMULAS_TO_INSTALL+=("$formula")
		fi
	done
}
