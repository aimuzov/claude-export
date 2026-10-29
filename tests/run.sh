#!/bin/sh
# Runs claude-export against fake manifests and a fake browser.
# Usage: sh tests/run.sh

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cli=$root/bin/claude-export
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

passed=0
failed=0

check() {
	if "$@"; then
		passed=$((passed + 1))
	else
		failed=$((failed + 1))
		printf 'FAIL: %s\n' "$label" >&2
		sed 's/^/  | /' "$tmp/out" >&2
	fi
}

has() { grep -qF -- "$1" "$tmp/out"; }
code_is() { [ "$code" -eq "$1" ]; }

run() {
	label=$1
	shift
	"$cli" "$@" >"$tmp/out" 2>&1
	code=$?
}

# A zip from this export and one from an older export with the same name
mkdir -p "$tmp/src" "$tmp/dl"
echo '[]' >"$tmp/src/conversations.json"
(cd "$tmp/src" && zip -q ../fresh.zip conversations.json)

manifest() {
	cat >"$tmp/$1" <<EOF
{"created_at":"2026-10-29T06:16:42.951205+00:00","version":"1.0","data_files":[$2]}
EOF
}

entry() { printf '{"category":"%s","filename":"%s-000.zip","export_url":"https://x/%s"}' "$1" "$1" "$1"; }

# The fake browser: "ok" downloads through a .crdownload, "slow" never
# finishes, anything else is a used link that opens no download
cat >"$tmp/open" <<EOF
#!/bin/sh
case \$1 in
	*/ok) (sleep 1; touch "$tmp/dl/Unconfirmed 1.crdownload"; sleep 1;
		cp "$tmp/fresh.zip" "$tmp/dl/ok-000.zip"; rm -f "$tmp/dl/Unconfirmed 1.crdownload") & ;;
	*/slow) (sleep 1; touch "$tmp/dl/slow-000.zip.crdownload") & ;;
esac
EOF
chmod +x "$tmp/open"
export CLAUDE_EXPORT_OPEN="$tmp/open"

cp "$tmp/fresh.zip" "$tmp/dl/local-000.zip"
cp "$tmp/fresh.zip" "$tmp/dl/renamed-000.zip"
touch -t 202601010000 "$tmp/dl/renamed-000.zip"
cp "$tmp/fresh.zip" "$tmp/dl/renamed-000 (1).zip"
cp "$tmp/fresh.zip" "$tmp/dl/stale-000.zip"
touch -t 202601010000 "$tmp/dl/stale-000.zip"
echo '<html>' >"$tmp/dl/broken-000.zip"

manifest m.json "$(entry local),$(entry renamed),$(entry ok),$(entry stale),$(entry slow),$(entry broken)"
run "full run" -f "$tmp/dl" -t 4 "$tmp/m.json" "$tmp/out1"
check code_is 1
check has "local-000.zip ← $tmp/dl/local-000.zip"
check has "renamed-000.zip ← $tmp/dl/renamed-000 (1).zip"
check has "ok-000.zip ← $tmp/dl/ok-000.zip"
check has "stale-000.zip download did not start"
check has "slow-000.zip did not finish in 4s"
check has "broken-000.zip is not a valid zip"
check has "3 ok, 3 failed"
check test -f "$tmp/out1/2026-10-29T06-16-42/local/conversations.json"
check test -f "$tmp/out1/2026-10-29T06-16-42/manifest.json"
check test ! -e "$tmp/out1/2026-10-29T06-16-42/.opened"

manifest r.json "$(entry local)"
run "rerun skips what is in the backup" -f "$tmp/dl" "$tmp/r.json" "$tmp/out1"
check code_is 0
check has "local-000.zip already in backup"

echo '{"version":"1.0","data_files":[{"category":"stale","filename":"stale-000.zip","export_url":"https://x/stale"}]}' >"$tmp/nodate.json"
run "no created_at takes any matching zip" -f "$tmp/dl" "$tmp/nodate.json" "$tmp/out2"
check code_is 0
check has "no created_at in manifest"

manifest e.json ""
run "empty manifest" "$tmp/e.json" "$tmp/out3"
check code_is 1
check has "lists no data_files"

echo '{oops' >"$tmp/b.json"
run "broken manifest" "$tmp/b.json" "$tmp/out3"
check code_is 1

manifest s.json '{"category":"..","filename":"x.zip","export_url":"https://x/x"}'
run "suspicious entry" -f "$tmp/dl" "$tmp/s.json" "$tmp/out3"
check code_is 1
check has "skipping a suspicious entry"

run "missing manifest" "$tmp/none.json"
check code_is 1

run "bad timeout" -t 0 "$tmp/m.json"
check code_is 2

run "no arguments"
check code_is 2

run "version" -V
check has "claude-export "

printf '%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
