#!/usr/bin/env bash
# The curl installer must pass the export choice required by full uninstall.
set -euo pipefail

root_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
test_home="$test_dir/home"
mkdir -p "$test_home/.reachable/venv/bin" "$test_dir/app"
mkdir -p "$test_dir/stubs"
cat > "$test_dir/stubs/curl" <<'EOF'
#!/usr/bin/env bash
printf 'unexpected network request\n' >&2
exit 91
EOF
chmod +x "$test_dir/stubs/curl"
export PATH="$test_dir/stubs:$PATH"
cat > "$test_home/.reachable/venv/bin/reachctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$HOME/uninstall-args"
EOF
chmod +x "$test_home/.reachable/venv/bin/reachctl"

if (cd "$test_dir/app" && HOME="$test_home" bash "$root_dir/install.sh" --uninstall --yes > "$test_dir/no-choice.out" 2>&1); then
    echo "uninstall accepted --yes without an export choice" >&2
    exit 1
fi
test ! -e "$test_home/uninstall-args"

(cd "$test_dir/app" && HOME="$test_home" bash "$root_dir/install.sh" --uninstall --yes --no-export > "$test_dir/no-export.out")
expected=$'vibe\nuninstall\n--full\n--yes\n--workspace\n'"$test_dir/app"$'\n--no-export'
test "$(cat "$test_home/uninstall-args")" = "$expected"

(cd "$test_dir/app" && HOME="$test_home" bash "$root_dir/install.sh" --uninstall --yes --export "$test_dir/backup.tar.gz" > "$test_dir/export.out")
expected=$'vibe\nuninstall\n--full\n--yes\n--workspace\n'"$test_dir/app"$'\n--export\n'"$test_dir/backup.tar.gz"
test "$(cat "$test_home/uninstall-args")" = "$expected"

mkdir -p "$test_dir/backup folder"
(cd "$test_dir/app" && HOME="$test_home" bash "$root_dir/install.sh" --uninstall --yes --export "$test_dir/backup folder/history.tar.gz" > "$test_dir/spaced-export.out")
expected=$'vibe\nuninstall\n--full\n--yes\n--workspace\n'"$test_dir/app"$'\n--export\n'"$test_dir/backup folder/history.tar.gz"
test "$(cat "$test_home/uninstall-args")" = "$expected"

rm "$test_home/uninstall-args"
if (cd "$test_dir/app" && HOME="$test_home" bash "$root_dir/install.sh" --uninstall --yes --export "$test_dir/backup.tar.gz" --no-export > "$test_dir/conflict.out" 2>&1); then
    echo "uninstall accepted conflicting export choices" >&2
    exit 1
fi
test ! -e "$test_home/uninstall-args"

rm "$test_home/.reachable/venv/bin/reachctl"
if (cd "$test_dir/app" && HOME="$test_home" bash "$root_dir/install.sh" --uninstall --yes --no-export > "$test_dir/no-runtime.out" 2>&1); then
    echo "uninstall claimed success without its runtime" >&2
    exit 1
fi
test -d "$test_home/.reachable"

echo "installer uninstall delegation passed"
