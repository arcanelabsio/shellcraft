#!/usr/bin/env bash

SHELLCRAFT_HOME=""
MANAGED_ZPROFILE=""
MANAGED_ZSHRC=""
MANAGED_GITCONFIG=""
MANAGED_TMUX_CONF=""
MANAGED_GITIGNORE=""
MANAGED_LOCAL_ZSH=""
MANAGED_STATE_ENV=""

MANAGED_CREATE_ACTIONS=()
MANAGED_UPDATE_ACTIONS=()
TOPLEVEL_CREATE_ACTIONS=()
TOPLEVEL_UPDATE_ACTIONS=()
DOCKER_CONFIG_ACTIONS=()

init_shellcraft_paths() {
	SHELLCRAFT_HOME="$HOME/.config/shellcraft"
	MANAGED_ZPROFILE="$SHELLCRAFT_HOME/zprofile.sh"
	MANAGED_ZSHRC="$SHELLCRAFT_HOME/zshrc.zsh"
	MANAGED_GITCONFIG="$SHELLCRAFT_HOME/gitconfig"
	MANAGED_TMUX_CONF="$SHELLCRAFT_HOME/tmux.conf"
	MANAGED_GITIGNORE="$SHELLCRAFT_HOME/gitignore_global"
	MANAGED_LOCAL_ZSH="$SHELLCRAFT_HOME/local.zsh"
	MANAGED_STATE_ENV="$SHELLCRAFT_HOME/state.env"
}

backup_if_exists() {
	local path="$1"

	if [[ -e "$path" ]]; then
		mkdir -p "$BACKUP_DIR"
		cp "$path" "$BACKUP_DIR/$(basename "$path")"
	fi
}

render_text_template() {
	local template_path="$1"
	local output_path="$2"
	local line

	while IFS= read -r line || [[ -n "$line" ]]; do
		case "$line" in
		__PLUGINS__)
			render_plugin_block >>"$output_path"
			;;
		__PROFILE_SNIPPETS__)
			render_snippet_block >>"$output_path"
			;;
		*)
			printf '%s\n' "$line" >>"$output_path"
			;;
		esac
	done <"$template_path"
}

render_plugin_block() {
	local plugin

	if [[ ${#SELECTED_PLUGINS[@]} -eq 0 ]]; then
		printf '    git\n'
		return 0
	fi

	for plugin in "${SELECTED_PLUGINS[@]}"; do
		printf '    %s\n' "$plugin"
	done
}

render_snippet_block() {
	local snippet

	for snippet in "${SELECTED_SNIPPETS[@]}"; do
		printf '%s\n' "$snippet"
		printf '\n'
	done
}

render_state_file() {
	local output_path="$1"

	{
		printf 'SHELLCRAFT_PROFILES="%s"\n' "$(join_by "," "${SELECTED_PROFILES[@]}")"
		printf 'SHELLCRAFT_WITH_FONTS="%s"\n' "$WITH_FONTS"
		printf 'SHELLCRAFT_SET_DEFAULT_SHELL="%s"\n' "$SET_DEFAULT_SHELL"
		printf 'SHELLCRAFT_ALLOW_GUI_INSTALLS="%s"\n' "$ALLOW_GUI_INSTALLS"
	} >>"$output_path"
}

render_managed_files() {
	local tmpdir="$1"

	init_shellcraft_paths
	mkdir -p "$tmpdir"

	cp "$SCRIPT_DIR/templates/zprofile.sh" "$tmpdir/zprofile.sh"
	: >"$tmpdir/zshrc.zsh"
	render_text_template "$SCRIPT_DIR/templates/zshrc.zsh" "$tmpdir/zshrc.zsh"
	cp "$SCRIPT_DIR/templates/gitconfig" "$tmpdir/gitconfig"
	cp "$SCRIPT_DIR/templates/tmux.conf" "$tmpdir/tmux.conf"
	cp "$SCRIPT_DIR/templates/gitignore_global" "$tmpdir/gitignore_global"

	if [[ ! -f "$MANAGED_LOCAL_ZSH" ]]; then
		cp "$SCRIPT_DIR/templates/local.zsh" "$tmpdir/local.zsh"
	fi

	: >"$tmpdir/state.env"
	render_state_file "$tmpdir/state.env"
}

plan_managed_file() {
	local target_path="$1"
	local rendered_path="$2"
	local label="$3"

	if [[ ! -e "$target_path" ]]; then
		MANAGED_CREATE_ACTIONS+=("$label -> $target_path")
	elif ! cmp -s "$target_path" "$rendered_path"; then
		MANAGED_UPDATE_ACTIONS+=("$label -> $target_path")
	fi
}

plan_managed_files() {
	local tmpdir="$1"

	MANAGED_CREATE_ACTIONS=()
	MANAGED_UPDATE_ACTIONS=()

	render_managed_files "$tmpdir"
	plan_managed_file "$MANAGED_ZPROFILE" "$tmpdir/zprofile.sh" "managed zprofile"
	plan_managed_file "$MANAGED_ZSHRC" "$tmpdir/zshrc.zsh" "managed zshrc"
	plan_managed_file "$MANAGED_GITCONFIG" "$tmpdir/gitconfig" "managed gitconfig"
	plan_managed_file "$MANAGED_TMUX_CONF" "$tmpdir/tmux.conf" "managed tmux config"
	plan_managed_file "$MANAGED_GITIGNORE" "$tmpdir/gitignore_global" "managed gitignore"
	if [[ -f "$tmpdir/local.zsh" ]]; then
		plan_managed_file "$MANAGED_LOCAL_ZSH" "$tmpdir/local.zsh" "local zsh overrides"
	fi
	plan_managed_file "$MANAGED_STATE_ENV" "$tmpdir/state.env" "managed state file"
}

file_contains_line() {
	local path="$1"
	local text="$2"

	[[ -f "$path" ]] && grep -Fqx "$text" "$path"
}

plan_top_level_adoption() {
	TOPLEVEL_CREATE_ACTIONS=()
	TOPLEVEL_UPDATE_ACTIONS=()

	if [[ ! -f "$HOME/.zprofile" ]]; then
		TOPLEVEL_CREATE_ACTIONS+=("$HOME/.zprofile")
	elif ! grep -Fq "$MANAGED_ZPROFILE" "$HOME/.zprofile"; then
		TOPLEVEL_UPDATE_ACTIONS+=("$HOME/.zprofile")
	fi

	if [[ ! -f "$HOME/.zshrc" ]]; then
		TOPLEVEL_CREATE_ACTIONS+=("$HOME/.zshrc")
	elif ! grep -Fq "$MANAGED_ZSHRC" "$HOME/.zshrc"; then
		TOPLEVEL_UPDATE_ACTIONS+=("$HOME/.zshrc")
	fi

	if [[ ! -f "$HOME/.gitconfig" ]]; then
		TOPLEVEL_CREATE_ACTIONS+=("$HOME/.gitconfig")
	elif ! grep -Fq "$MANAGED_GITCONFIG" "$HOME/.gitconfig"; then
		TOPLEVEL_UPDATE_ACTIONS+=("$HOME/.gitconfig")
	fi

	if [[ ! -f "$HOME/.tmux.conf" ]]; then
		TOPLEVEL_CREATE_ACTIONS+=("$HOME/.tmux.conf")
	elif ! grep -Fq "$MANAGED_TMUX_CONF" "$HOME/.tmux.conf"; then
		TOPLEVEL_UPDATE_ACTIONS+=("$HOME/.tmux.conf")
	fi
}

apply_managed_file() {
	local target_path="$1"
	local rendered_path="$2"

	mkdir -p "$(dirname "$target_path")"

	if [[ ! -e "$target_path" ]] || ! cmp -s "$target_path" "$rendered_path"; then
		cp "$rendered_path" "$target_path"
	fi
}

# Adds the managed block once. Placement "top" is for files where later
# settings win (gitconfig, tmux.conf): putting Shellcraft first lets the
# user's own lines override it. An existing block is never moved.
add_block_if_missing() {
	local path="$1"
	local block="$2"
	local marker="$3"
	local placement="${4:-bottom}"
	local tmpfile

	if [[ -f "$path" ]] && grep -Fq "$marker" "$path"; then
		return 0
	fi

	if [[ -f "$path" ]] && grep -Fq "$block" "$path"; then
		return 0
	fi

	if [[ -f "$path" ]]; then
		backup_if_exists "$path"
		if [[ "$placement" == "top" ]]; then
			tmpfile="$(mktemp "${TMPDIR:-/tmp}/shellcraft-adopt.XXXXXX")"
			{
				printf '%s\n\n' "$block"
				cat "$path"
			} >"$tmpfile"
			cat "$tmpfile" >"$path"
			rm -f "$tmpfile"
		else
			printf '\n%s\n' "$block" >>"$path"
		fi
	else
		printf '%s\n' "$block" >"$path"
	fi
}

apply_top_level_adoption() {
	add_block_if_missing "$HOME/.zprofile" "# >>> shellcraft >>>
[[ -f \"$HOME/.config/shellcraft/zprofile.sh\" ]] && source \"$HOME/.config/shellcraft/zprofile.sh\"
# <<< shellcraft <<<" "# >>> shellcraft >>>"

	add_block_if_missing "$HOME/.zshrc" "# >>> shellcraft >>>
[[ -f \"$HOME/.config/shellcraft/zshrc.zsh\" ]] && source \"$HOME/.config/shellcraft/zshrc.zsh\"
# <<< shellcraft <<<" "# >>> shellcraft >>>"

	add_block_if_missing "$HOME/.gitconfig" "# >>> shellcraft >>>
[include]
    path = ~/.config/shellcraft/gitconfig
# <<< shellcraft <<<" "path = ~/.config/shellcraft/gitconfig" top

	add_block_if_missing "$HOME/.tmux.conf" "# >>> shellcraft >>>
source-file ~/.config/shellcraft/tmux.conf
# <<< shellcraft <<<" "source-file ~/.config/shellcraft/tmux.conf" top
}

apply_managed_files() {
	local tmpdir="$1"

	render_managed_files "$tmpdir"

	apply_managed_file "$MANAGED_ZPROFILE" "$tmpdir/zprofile.sh"
	apply_managed_file "$MANAGED_ZSHRC" "$tmpdir/zshrc.zsh"
	apply_managed_file "$MANAGED_GITCONFIG" "$tmpdir/gitconfig"
	apply_managed_file "$MANAGED_TMUX_CONF" "$tmpdir/tmux.conf"
	apply_managed_file "$MANAGED_GITIGNORE" "$tmpdir/gitignore_global"
	if [[ -f "$tmpdir/local.zsh" ]]; then
		apply_managed_file "$MANAGED_LOCAL_ZSH" "$tmpdir/local.zsh"
	fi
	apply_managed_file "$MANAGED_STATE_ENV" "$tmpdir/state.env"

	apply_top_level_adoption
}

plan_docker_config() {
	local docker_config="$HOME/.docker/config.json"
	local plugin_dir="$BREW_PREFIX/lib/docker/cli-plugins"

	DOCKER_CONFIG_ACTIONS=()

	if ! array_contains containers "${SELECTED_PROFILES[@]}"; then
		return 0
	fi

	if [[ ! -f "$docker_config" ]]; then
		DOCKER_CONFIG_ACTIONS+=("create ~/.docker/config.json with cliPluginsExtraDirs")
		return 0
	fi

	if ! grep -Fq "$plugin_dir" "$docker_config"; then
		DOCKER_CONFIG_ACTIONS+=("update ~/.docker/config.json with cliPluginsExtraDirs")
	fi
}

apply_docker_config() {
	local docker_dir="$HOME/.docker"
	local docker_config="$docker_dir/config.json"
	local plugin_dir="$BREW_PREFIX/lib/docker/cli-plugins"

	if ! array_contains containers "${SELECTED_PROFILES[@]}"; then
		return 0
	fi

	mkdir -p "$docker_dir"

	if command -v ruby >/dev/null 2>&1; then
		if [[ -f "$docker_config" ]]; then
			backup_if_exists "$docker_config"
		fi

		ruby -r json -e '
path = ARGV[0]
plugin_dir = ARGV[1]
data = {}

if File.exist?(path) && !File.read(path).strip.empty?
  data = JSON.parse(File.read(path))
end

dirs = data["cliPluginsExtraDirs"]
dirs = [] unless dirs.is_a?(Array)

unless dirs.include?(plugin_dir)
  dirs << plugin_dir
  data["cliPluginsExtraDirs"] = dirs
  File.write(path, JSON.pretty_generate(data) + "\n")
end
' "$docker_config" "$plugin_dir"
	else
		warn "ruby not found; skipping ~/.docker/config.json merge"
	fi
}
