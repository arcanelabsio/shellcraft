setup_test_env() {
    local root="${BATS_TEST_TMPDIR:-$(mktemp -d "${TMPDIR:-/tmp}/shellcraft-tests.XXXXXX")}"

    export TEST_HOME="$root/home"
    export TEST_BIN="$root/bin"
    export TEST_BREW_PREFIX="$TEST_HOME/homebrew"
    export HOME="$TEST_HOME"
    export PATH="$TEST_BIN:/usr/bin:/bin:/usr/sbin:/sbin"

    mkdir -p "$TEST_HOME" "$TEST_BIN" "$TEST_BREW_PREFIX/bin"
    touch "$TEST_HOME/.brew-state"

    cat > "$TEST_BIN/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-m" ]]; then
    echo "${SHELLCRAFT_TEST_ARCH:-arm64}"
else
    echo "Darwin"
fi
EOF
    chmod +x "$TEST_BIN/uname"

    cat > "$TEST_BIN/brew" <<'EOF'
#!/usr/bin/env bash
state_file="$HOME/.brew-state"
prefix="${TEST_BREW_PREFIX:-$HOME/homebrew}"
bin_dir="$prefix/bin"

has_state() {
    grep -qx "$1" "$state_file" 2>/dev/null
}

formula_cmd() {
    case "$1" in
        ripgrep) echo "rg" ;;
        git-delta) echo "delta" ;;
        neovim) echo "nvim" ;;
        gnu-sed) echo "gsed" ;;
        kubernetes-cli) echo "kubectl" ;;
        bats-core) echo "bats" ;;
        markdownlint-cli) echo "markdownlint" ;;
        go-task) echo "task" ;;
        *) echo "$1" ;;
    esac
}

write_bin() {
    local formula="$1"
    local cmd
    mkdir -p "$bin_dir"
    cmd="$(formula_cmd "$formula")"
    cat > "$bin_dir/$cmd" <<SCRIPT
#!/usr/bin/env bash
echo "$cmd stub"
SCRIPT
    chmod +x "$bin_dir/$cmd"
}

add_state() {
    if ! has_state "$1"; then
        printf '%s\n' "$1" >> "$state_file"
    fi
    case "$1" in
        cask:*)
            ;;
        *)
            write_bin "$1"
            ;;
    esac
}

case "$1" in
    --prefix)
        echo "$prefix"
        ;;
    shellenv)
        echo "export PATH=\"$prefix/bin:\$PATH\""
        ;;
    --version)
        echo "Homebrew 4.4.0"
        ;;
    update|cleanup)
        ;;
    outdated)
        if [[ "$2" == "--quiet" ]] && [[ -n "${SHELLCRAFT_TEST_BREW_OUTDATED:-}" ]]; then
            printf '%s\n' ${SHELLCRAFT_TEST_BREW_OUTDATED}
        fi
        ;;
    list)
        if [[ "$2" == "--formula" ]]; then
            has_state "$3"
        elif [[ "$2" == "--cask" ]]; then
            has_state "cask:$3"
        else
            exit 1
        fi
        ;;
    install)
        shift
        if [[ "$1" == "--cask" ]]; then
            add_state "cask:$2"
            exit 0
        fi
        while [[ $# -gt 0 ]]; do
            if [[ "$1" != --* ]]; then
                add_state "$1"
                exit 0
            fi
            shift
        done
        ;;
    upgrade)
        shift
        while [[ $# -gt 0 ]]; do
            if [[ "$1" != --* ]]; then
                add_state "$1"
            fi
            shift
        done
        ;;
    *)
        ;;
esac
EOF
    chmod +x "$TEST_BIN/brew"

    cat > "$TEST_BIN/git" <<'EOF'
#!/usr/bin/env bash
real_git="/usr/bin/git"

if [[ "$1" == "clone" ]]; then
    dest="${@: -1}"
    mkdir -p "$dest/.git"
    case "$dest" in
        */.oh-my-zsh)
            touch "$dest/oh-my-zsh.sh"
            ;;
        */powerlevel10k)
            ;;
        */zsh-autosuggestions)
            touch "$dest/zsh-autosuggestions.zsh"
            ;;
        */zsh-syntax-highlighting)
            touch "$dest/zsh-syntax-highlighting.zsh"
            ;;
    esac
    exit 0
fi

if [[ "$1" == "-C" && "$3" == "pull" ]]; then
    exit 0
fi

exec "$real_git" "$@"
EOF
    chmod +x "$TEST_BIN/git"

    cat > "$TEST_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
marker="$HOME/.xcode-present"

if [[ "${SHELLCRAFT_TEST_XCODE_MISSING:-0}" != "1" ]]; then
    touch "$marker"
fi

case "$1" in
    -p)
        if [[ -f "$marker" ]]; then
            echo "/Library/Developer/CommandLineTools"
            exit 0
        fi
        exit 1
        ;;
    --install)
        touch "$HOME/.xcode-install-invoked"
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_BIN/xcode-select"

    cat > "$TEST_BIN/softwareupdate" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-l" ]]; then
    echo "Command Line Tools for Xcode-16.0"
elif [[ "$1" == "-i" ]]; then
    touch "$HOME/.xcode-present"
fi
EOF
    chmod +x "$TEST_BIN/softwareupdate"

    cat > "$TEST_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-v" || "$1" == "-n" ]]; then
    exit 0
fi
exec "$@"
EOF
    chmod +x "$TEST_BIN/sudo"

    cat > "$TEST_BIN/dscl" <<'EOF'
#!/usr/bin/env bash
echo "UserShell: /bin/zsh"
EOF
    chmod +x "$TEST_BIN/dscl"

    cat > "$TEST_BIN/chsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$TEST_BIN/chsh"

    cat > "$TEST_BIN/ruby" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/ruby "$@"
EOF
    chmod +x "$TEST_BIN/ruby"
}

seed_brew_state() {
    : > "$HOME/.brew-state"
    for formula in "$@"; do
        printf '%s\n' "$formula" >> "$HOME/.brew-state"
    done
}

assert_file_contains() {
    local path="$1"
    local expected="$2"
    grep -Fq "$expected" "$path"
}
