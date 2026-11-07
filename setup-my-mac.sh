#!/usr/bin/env bash

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="plan"
FIX_DOCTOR=0
WITH_FONTS=0
SET_DEFAULT_SHELL=0
ALLOW_GUI_INSTALLS=0
REQUESTED_PROFILES=()
BREW_PREFIX=""
BREW_BIN=""
BREW_OUTDATED_CACHE=""
TMP_RENDER_DIR=""
LOG_FILE=""
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
SUDO_KEEPER_PID=""
SUCCESS_COUNT=0
FAIL_COUNT=0
WARNING_COUNT=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() {
	if [[ -n "$LOG_FILE" ]]; then
		echo "[$(date '+%H:%M:%S')] $1" >>"$LOG_FILE"
	fi
}

info() {
	echo -e "  ${BLUE}▸${NC} $1"
	log "INFO: $1"
}

success() {
	echo -e "  ${GREEN}✔${NC} $1"
	log "OK: $1"
	SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
}

warn() {
	echo -e "  ${YELLOW}⚠${NC} $1"
	log "WARN: $1"
	WARNING_COUNT=$((WARNING_COUNT + 1))
}

fail() {
	echo -e "  ${RED}✘${NC} $1"
	log "FAIL: $1"
	FAIL_COUNT=$((FAIL_COUNT + 1))
}

section() {
	echo ""
	echo -e "${CYAN}${BOLD}$1${NC}"
}

cleanup() {
	if [[ -n "$SUDO_KEEPER_PID" ]]; then
		kill "$SUDO_KEEPER_PID" 2>/dev/null || true
	fi
	if [[ -n "$TMP_RENDER_DIR" ]] && [[ -d "$TMP_RENDER_DIR" ]]; then
		rm -rf "$TMP_RENDER_DIR"
	fi
}
trap cleanup EXIT

usage() {
	cat <<'EOF'
Shellcraft

Usage:
  ./setup-my-mac.sh --plan --profile core
  ./setup-my-mac.sh --apply --profile core --profile maintainer
  ./setup-my-mac.sh --apply --profile core --profile backend --profile ai --profile maintainer
  ./setup-my-mac.sh --apply --profile containers --with-fonts --set-default-shell
  ./setup-my-mac.sh --doctor --profile core
  ./setup-my-mac.sh --doctor --fix --profile core

Flags:
  --plan               Preview actions without mutating the machine (default)
  --apply              Execute the selected plan
  --doctor             Run non-mutating verification
  --fix                With --doctor, repair missing formulas and managed config
  --profile <name>     Repeatable. core, backend, ai, maintainer, containers, local-ai, all
  --with-fonts         Install MesloLGS Nerd Font during apply
  --set-default-shell  Change the login shell to zsh during apply
  --allow-gui-installs Allow GUI-assisted Xcode CLT fallback during apply
  --help               Show this help text
EOF
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--plan)
			MODE="plan"
			;;
		--apply)
			MODE="apply"
			;;
		--doctor)
			MODE="doctor"
			;;
		--fix)
			FIX_DOCTOR=1
			;;
		--profile)
			if [[ $# -lt 2 ]]; then
				echo "Missing value for --profile" >&2
				exit 1
			fi
			REQUESTED_PROFILES+=("$2")
			shift
			;;
		--with-fonts)
			WITH_FONTS=1
			;;
		--set-default-shell)
			SET_DEFAULT_SHELL=1
			;;
		--allow-gui-installs)
			ALLOW_GUI_INSTALLS=1
			;;
		--help | -h)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage
			exit 1
			;;
		esac
		shift
	done
}

detect_brew_prefix() {
	if [[ "$(uname -m)" == "arm64" ]]; then
		BREW_PREFIX="/opt/homebrew"
	else
		BREW_PREFIX="/usr/local"
	fi

	if command -v brew >/dev/null 2>&1; then
		BREW_PREFIX="$(brew --prefix)"
	fi
}

setup_brew_path() {
	if resolve_brew_binary >/dev/null 2>&1; then
		eval "$("$BREW_BIN" shellenv)"
		BREW_PREFIX="$("$BREW_BIN" --prefix)"
	fi
}

acquire_sudo() {
	if [[ -n "$SUDO_KEEPER_PID" ]]; then
		return 0
	fi

	if ! sudo -v; then
		fail "Unable to acquire sudo"
		return 1
	fi

	while true; do
		sudo -n true
		sleep 50
		kill -0 "$$" || exit
	done 2>/dev/null &
	SUDO_KEEPER_PID=$!
	return 0
}

source "$SCRIPT_DIR/lib/profile_metadata.sh"
source "$SCRIPT_DIR/lib/planner.sh"
source "$SCRIPT_DIR/lib/config_adoption.sh"
source "$SCRIPT_DIR/lib/verifier.sh"

print_list() {
	local title="$1"
	shift
	local values=("$@")
	local value

	echo ""
	echo "$title"
	if [[ ${#values[@]} -eq 0 ]]; then
		echo "  - none"
		return 0
	fi

	for value in "${values[@]}"; do
		echo "  - $value"
	done
}

has_xcode_cli() {
	xcode-select -p >/dev/null 2>&1
}

should_install_zsh_stack() {
	array_contains core "${SELECTED_PROFILES[@]}"
}

font_installed() {
	if ! brew_available; then
		return 1
	fi
	"$BREW_BIN" list --cask font-meslo-lg-nerd-font >/dev/null 2>&1
}

print_plan() {
	local blocked_changes=()
	local sudo_required="no"

	section "Shellcraft Plan"
	echo "Mode: $MODE"
	echo "Profiles: $(join_by ", " "${SELECTED_PROFILES[@]}")"
	echo "Homebrew prefix: $BREW_PREFIX"

	if has_xcode_cli; then
		echo "Xcode CLI Tools: installed"
	else
		echo "Xcode CLI Tools: missing"
		if [[ $ALLOW_GUI_INSTALLS -eq 0 ]]; then
			blocked_changes+=("Xcode CLI Tools install blocked until --allow-gui-installs is passed")
		fi
	fi

	if brew_available; then
		echo "Homebrew: installed"
	else
		echo "Homebrew: missing"
	fi

	print_list "Selected formulas" "${SELECTED_FORMULAS[@]}"
	if [[ -f "$(local_brewfile_path)" ]]; then
		print_list "Formulas from local.Brewfile" "${LOCAL_FORMULAS[@]}"
		if [[ $LOCAL_SKIPPED_LINES -gt 0 ]]; then
			echo "local.Brewfile: $LOCAL_SKIPPED_LINES cask/tap/mas/vscode line(s) skipped; Shellcraft installs formulas only"
		fi
	fi
	print_list "Formulas to install" "${FORMULAS_TO_INSTALL[@]}"
	print_list "Selected formulas already installed" "${FORMULAS_INSTALLED[@]}"
	print_list "Selected formulas to upgrade" "${FORMULAS_TO_UPGRADE[@]}"
	print_list "Managed files to create" "${MANAGED_CREATE_ACTIONS[@]}"
	print_list "Managed files to update" "${MANAGED_UPDATE_ACTIONS[@]}"
	print_list "Top-level files to create" "${TOPLEVEL_CREATE_ACTIONS[@]}"
	print_list "Top-level files to update" "${TOPLEVEL_UPDATE_ACTIONS[@]}"
	print_list "Docker config changes" "${DOCKER_CONFIG_ACTIONS[@]}"

	if [[ $WITH_FONTS -eq 1 ]]; then
		if font_installed; then
			print_list "Optional casks to install"
		else
			print_list "Optional casks to install" "font-meslo-lg-nerd-font"
		fi
	else
		blocked_changes+=("Font install blocked until --with-fonts is passed")
	fi

	if [[ $SET_DEFAULT_SHELL -eq 0 ]]; then
		blocked_changes+=("Default shell change blocked until --set-default-shell is passed")
	fi

	if [[ ${#blocked_changes[@]} -gt 0 ]]; then
		print_list "Blocked system changes" "${blocked_changes[@]}"
	fi

	if [[ ! -f "$HOME/.gitconfig" ]] || ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
		echo ""
		echo "Git identity:"
		echo "  - Shellcraft will not write placeholder values"
		echo "  - Set user.name and user.email yourself if they are missing"
	fi

	if { ! has_xcode_cli && [[ $ALLOW_GUI_INSTALLS -eq 1 ]]; } || [[ $SET_DEFAULT_SHELL -eq 1 ]]; then
		sudo_required="yes"
	fi

	echo ""
	echo "Sudo required during apply: $sudo_required"
}

ensure_xcode() {
	local product

	section "Xcode CLI Tools"

	if has_xcode_cli; then
		success "Xcode CLI Tools already installed"
		return 0
	fi

	if [[ $ALLOW_GUI_INSTALLS -eq 0 ]]; then
		fail "Xcode CLI Tools are missing"
		echo "  Run again with --allow-gui-installs after reviewing the change."
		return 1
	fi

	acquire_sudo || return 1
	info "Installing Xcode CLI Tools"
	touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
	product="$(softwareupdate -l 2>/dev/null | grep -B 1 "Command Line Tools" | grep -o 'Command Line Tools.*' | head -1)"

	if [[ -n "$product" ]]; then
		sudo softwareupdate -i "$product" --verbose >/dev/null 2>&1
	else
		info "Falling back to GUI-assisted Xcode CLI Tools install"
		xcode-select --install >/dev/null 2>&1 || true
	fi

	rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

	if has_xcode_cli; then
		success "Xcode CLI Tools installed"
		return 0
	fi

	fail "Xcode CLI Tools installation did not complete"
	return 1
}

ensure_homebrew() {
	section "Homebrew"
	export NONINTERACTIVE=1
	export HOMEBREW_NO_INSTALL_CLEANUP=1

	if brew_available; then
		setup_brew_path
		success "Homebrew available"
		info "Updating Homebrew metadata"
		"$BREW_BIN" update --quiet >/dev/null 2>&1 || warn "brew update reported an error"
		return 0
	fi

	info "Installing Homebrew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
	if ! brew_available; then
		setup_brew_path
	fi

	if brew_available; then
		setup_brew_path
		success "Homebrew installed"
		return 0
	fi

	fail "Homebrew install failed"
	return 1
}

install_formulas() {
	local formula

	section "Profiles"

	for formula in "${FORMULAS_TO_INSTALL[@]}"; do
		info "Installing $formula"
		if "$BREW_BIN" install "$formula" --quiet >/dev/null 2>&1; then
			success "$formula installed"
		else
			fail "$formula installation failed"
		fi
	done

	if [[ ${#FORMULAS_TO_UPGRADE[@]} -gt 0 ]]; then
		info "Upgrading selected outdated formulas"
		if "$BREW_BIN" upgrade "${FORMULAS_TO_UPGRADE[@]}" --quiet >/dev/null 2>&1; then
			success "Selected formulas upgraded"
		else
			fail "One or more selected formula upgrades failed"
		fi
	else
		success "Selected formulas already current"
	fi
}

install_missing_formulas() {
	local formula

	section "Repair Formulas"

	if [[ ${#FORMULAS_TO_INSTALL[@]} -eq 0 ]]; then
		success "No missing selected formulas to install"
		return 0
	fi

	for formula in "${FORMULAS_TO_INSTALL[@]}"; do
		info "Installing $formula"
		if "$BREW_BIN" install "$formula" --quiet >/dev/null 2>&1; then
			success "$formula installed"
		else
			fail "$formula installation failed"
		fi
	done
}

install_fonts_if_requested() {
	section "Fonts"

	if [[ $WITH_FONTS -eq 0 ]]; then
		warn "Font install skipped; pass --with-fonts to enable it"
		return 0
	fi

	if font_installed; then
		success "MesloLGS Nerd Font already installed"
		return 0
	fi

	info "Installing MesloLGS Nerd Font"
	if "$BREW_BIN" install --cask font-meslo-lg-nerd-font --quiet >/dev/null 2>&1; then
		success "MesloLGS Nerd Font installed"
	else
		fail "MesloLGS Nerd Font install failed"
	fi
}

install_or_update_git_repo() {
	local repo_url="$1"
	local destination="$2"
	local label="$3"

	if [[ -d "$destination/.git" ]]; then
		info "Updating $label"
		if git -C "$destination" pull --quiet >/dev/null 2>&1; then
			success "$label updated"
		else
			warn "$label update failed"
		fi
		return 0
	fi

	info "Installing $label"
	if git clone "$repo_url" "$destination" >/dev/null 2>&1; then
		success "$label installed"
	else
		fail "$label install failed"
	fi
}

install_zsh_stack() {
	if ! should_install_zsh_stack; then
		return 0
	fi

	section "Shell Stack"
	install_or_update_git_repo "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh" "Oh My Zsh"
	install_or_update_git_repo "https://github.com/romkatv/powerlevel10k.git" "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" "Powerlevel10k"
	install_or_update_git_repo "https://github.com/zsh-users/zsh-autosuggestions" "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "zsh-autosuggestions"
	install_or_update_git_repo "https://github.com/zsh-users/zsh-syntax-highlighting" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "zsh-syntax-highlighting"

	if command -v fzf >/dev/null 2>&1; then
		if [[ -x "$BREW_PREFIX/opt/fzf/install" ]] && [[ ! -f "$HOME/.fzf.zsh" ]]; then
			info "Installing fzf key bindings"
			"$BREW_PREFIX/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish </dev/null >/dev/null 2>&1 || warn "fzf key binding setup failed"
		fi
	fi
}

apply_config_adoption() {
	section "Managed Config"
	apply_managed_files "$TMP_RENDER_DIR"
	success "Managed Shellcraft files written"
}

apply_optional_system_changes() {
	local zsh_path

	section "System Changes"

	if [[ $SET_DEFAULT_SHELL -eq 1 ]]; then
		zsh_path="$(command -v zsh)"
		if [[ -n "$zsh_path" ]]; then
			acquire_sudo || return 1
			if sudo chsh -s "$zsh_path" "$(whoami)" >/dev/null 2>&1; then
				success "Default shell set to zsh"
			else
				fail "Unable to change the default shell"
			fi
		else
			fail "zsh not found in PATH"
		fi
	else
		warn "Default shell unchanged; pass --set-default-shell to enable it"
	fi

	apply_docker_config
	if [[ ${#DOCKER_CONFIG_ACTIONS[@]} -gt 0 ]]; then
		success "Docker CLI plugin path checked"
	fi
}

repair_doctor_findings() {
	local needs_changes=0
	local needs_brew_repairs=0

	if [[ ${#DOCTOR_MISSING_FORMULAS[@]} -gt 0 ]]; then
		needs_changes=1
		needs_brew_repairs=1
	fi

	if [[ ${#DOCTOR_PATH_FORMULAS[@]} -gt 0 ]]; then
		needs_changes=1
	fi

	if [[ ${#MANAGED_CREATE_ACTIONS[@]} -gt 0 ]] || [[ ${#MANAGED_UPDATE_ACTIONS[@]} -gt 0 ]] || [[ ${#TOPLEVEL_CREATE_ACTIONS[@]} -gt 0 ]] || [[ ${#TOPLEVEL_UPDATE_ACTIONS[@]} -gt 0 ]] || [[ ${#DOCKER_CONFIG_ACTIONS[@]} -gt 0 ]]; then
		needs_changes=1
	fi

	section "Doctor Repair"

	if [[ $needs_changes -eq 0 ]]; then
		success "No repair actions needed"
		return 0
	fi

	if [[ $needs_brew_repairs -eq 1 ]] || ! brew_available; then
		ensure_xcode || return 1
		ensure_homebrew || return 1
		compute_brew_plan
		install_missing_formulas
	fi

	if [[ ${#DOCTOR_PATH_FORMULAS[@]} -gt 0 ]]; then
		info "Refreshing managed config and brew shellenv for PATH consistency"
	fi

	if should_install_zsh_stack; then
		install_zsh_stack
	fi

	apply_config_adoption
	apply_docker_config
	setup_brew_path
	compute_brew_plan
	success "Doctor repair finished"
}

print_summary() {
	echo ""
	echo -e "${BOLD}Summary${NC}"
	echo "  Passed:  $SUCCESS_COUNT"
	echo "  Warnings: $WARNING_COUNT"
	echo "  Failed:  $FAIL_COUNT"
}

parse_args "$@"
export HOMEBREW_NO_AUTO_UPDATE=1

if [[ $FIX_DOCTOR -eq 1 ]] && [[ "$MODE" != "doctor" ]]; then
	echo "--fix can only be used with --doctor" >&2
	exit 1
fi

if [[ "$(uname)" != "Darwin" ]]; then
	echo "Shellcraft only supports macOS." >&2
	exit 1
fi

detect_brew_prefix

if ! resolve_selected_profiles "${REQUESTED_PROFILES[@]}"; then
	echo "$PLANNER_ERROR" >&2
	exit 1
fi

collect_selected_formulas
collect_selected_plugins
collect_selected_snippets
setup_brew_path

TMP_RENDER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/shellcraft.XXXXXX")"
plan_managed_files "$TMP_RENDER_DIR"
plan_top_level_adoption
plan_docker_config
compute_brew_plan

if [[ "$MODE" == "plan" ]]; then
	print_plan
	exit 0
fi

if [[ "$MODE" == "doctor" ]]; then
	init_shellcraft_paths
	run_doctor

	if [[ $FIX_DOCTOR -eq 1 ]]; then
		repair_doctor_findings || {
			print_summary
			exit 1
		}
		SUCCESS_COUNT=0
		FAIL_COUNT=0
		WARNING_COUNT=0
		init_shellcraft_paths
		run_doctor
	fi

	print_summary
	[[ $FAIL_COUNT -eq 0 ]]
	exit $?
fi

LOG_FILE="$HOME/.mac-dev-setup.log"
echo "=== Shellcraft apply run: $(date) ===" >"$LOG_FILE"

ensure_xcode || {
	print_summary
	exit 1
}

ensure_homebrew || {
	print_summary
	exit 1
}

compute_brew_plan
install_formulas
install_fonts_if_requested
install_zsh_stack
apply_config_adoption
apply_optional_system_changes

init_shellcraft_paths
run_doctor
print_summary

if [[ $FAIL_COUNT -gt 0 ]]; then
	exit 1
fi
