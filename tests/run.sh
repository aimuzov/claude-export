#!/bin/sh
# Runs claude-export against fake manifests and a fake browser.
# Usage: sh tests/run.sh [sh|fish]
#   sh    bin/claude-export (default)
#   fish  the claude.export function from functions/

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

case ${1:-sh} in
	sh) cli=$root/bin/claude-export ;;
	fish)
		# One executable for both, so every case below runs unchanged
		cli=$tmp/claude.export
		cat >"$cli" <<EOF
#!/bin/sh
exec fish --no-config -c 'source "\$argv[1]"; claude.export \$argv[2..]' "$root/functions/claude.export.fish" "\$@"
EOF
		chmod +x "$cli"
		;;
	*)
		echo "usage: sh tests/run.sh [sh|fish]" >&2
		exit 2
		;;
esac

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
check has "export 0."

run "long version" --version
check code_is 0
check has "export 0."

run "help" --help
check code_is 0
check has "--timeout seconds"

run "long options with a space" --from "$tmp/dl" --timeout 5 "$tmp/r.json" "$tmp/out4"
check code_is 0
check has "local-000.zip ← $tmp/dl/local-000.zip"

run "long options with =, after the manifest" "$tmp/r.json" "$tmp/out5" --from="$tmp/dl" --timeout=5
check code_is 0
check has "local-000.zip ← $tmp/dl/local-000.zip"

run "short options glued to the value" "-f$tmp/dl" -t5 "$tmp/r.json" "$tmp/out6"
check code_is 0

run "-- ends the options" -f "$tmp/dl" -- "$tmp/r.json" "$tmp/out7"
check code_is 0

run "unknown option" --nope "$tmp/r.json"
check code_is 2
check has "--nope"

run "option without a value" "$tmp/r.json" --from
check code_is 2
check has "--from"

run "bad long timeout" --timeout=abc "$tmp/r.json"
check code_is 2

run "too many arguments" "$tmp/r.json" "$tmp/out8" extra
check code_is 2
check has "unexpected argument: extra"

printf '%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
