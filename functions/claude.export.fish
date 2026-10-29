# claude.export: download a claude.ai data export by its manifest and unpack it.
# The fish twin of bin/claude-export, both pass the same tests/run.sh.
# https://github.com/aimuzov/claude-export

function claude.export --description 'Download a claude.ai data export by its manifest and unpack it'
    set -l prog claude.export
    set -l prog_version 0.2.0

    if not argparse --name $prog 'f/from=+' 't/timeout=' h/help V/version -- $argv
        printf "Try '%s --help' for more information.\n" $prog >&2
        return 2
    end

    if set -q _flag_help
        echo "Usage: $prog [options] <manifest.json> [dest_root]

Downloads every archive listed in a claude.ai data export manifest through
your browser and unpacks it by category into dest_root/<created_at>.

Options:
  -f, --from dir         folder the browser saves downloads to, repeatable
                         (default: the manifest's folder and ~/Downloads)
  -t, --timeout seconds  how long to wait for each download (default: 300)
  -h, --help             show this help
  -V, --version          show the version

Environment:
  CLAUDE_EXPORT_DEST  default dest_root (default: ~/claude-export)
  CLAUDE_EXPORT_OPEN  command that opens a URL (default: open)"
        return 0
    end

    if set -q _flag_version
        echo "$prog $prog_version"
        return 0
    end

    set -l timeout 300
    set -q _flag_timeout; and set timeout $_flag_timeout[-1]

    if not string match -qr '^[1-9][0-9]*$' -- $timeout
        echo "$prog: --timeout takes a positive number of seconds, got '$timeout'" >&2
        return 2
    end

    if test (count $argv) -eq 0
        echo "$prog: no manifest given" >&2
        return 2
    end

    if test (count $argv) -gt 2
        echo "$prog: unexpected argument: $argv[3]" >&2
        return 2
    end

    set -l manifest $argv[1]
    set -l dest_root $argv[2]
    test -n "$dest_root"; or set dest_root $CLAUDE_EXPORT_DEST
    test -n "$dest_root"; or set dest_root $HOME/claude-export

    if not test -f "$manifest"
        echo "$prog: manifest not found: $manifest" >&2
        return 1
    end

    for cmd in jq unzip find
        if not command -q $cmd
            echo "$prog: $cmd not found" >&2
            return 1
        end
    end

    if not jq -e '.data_files | type == "array" and length > 0' $manifest >/dev/null 2>&1
        echo "$prog: $manifest is not valid JSON or lists no data_files" >&2
        return 1
    end

    set -l manifest_version (jq -r '.version // empty' $manifest)
    if test "$manifest_version" != "1.0"
        echo "$prog: unexpected manifest version '$manifest_version', continuing anyway" >&2
    end

    # The browser saves the zips next to the manifest, which came the same way
    set -l sources $_flag_from
    test -n "$sources"; or set sources (path dirname $manifest) $HOME/Downloads

    set -l opener open
    set -q CLAUDE_EXPORT_OPEN; and set opener (string split ' ' -- $CLAUDE_EXPORT_OPEN)

    # 2026-10-29T06:16:42.951205+00:00 → 2026-10-29T06:16:42
    set -l created (jq -r '.created_at // empty | .[0:19]' $manifest)
    set -l since
    set -l stamp

    if test -n "$created"
        set stamp (string replace -a : - $created)

        # jq, not date: GNU date often shadows the BSD one on macOS
        set since (jq -nr --arg t $created '$t + "Z" | fromdateiso8601' 2>/dev/null)
        test -n "$since"; or echo "$prog: can't read created_at '$created', any zip with a matching name will do" >&2
    else
        echo "$prog: no created_at in manifest, any zip with a matching name will do" >&2
        set stamp (date -u +%Y-%m-%dT%H-%M-%S)
    end

    set -l dest $dest_root/$stamp
    mkdir -p $dest/zips; or return 1
    cp $manifest $dest/manifest.json

    set -l ok 0
    set -l failed

    # Links may die once opened, so a failed file must not stop the rest
    for row in (jq -r '.data_files[] | [.category, .filename, .export_url] | @tsv' $manifest)
        set -l fields (string split \t -- $row)
        set -l category $fields[1]
        set -l filename $fields[2]
        set -l url $fields[3]

        if string match -qr '^(\.|/)|/.*/|/\.|/$' -- "$category/$filename"
            echo "$prog: skipping a suspicious entry: '$category' '$filename'" >&2
            set -a failed $filename
            continue
        end

        set -l zip $dest/zips/$filename

        if test -f $zip
            echo "$prog: $filename already in backup"
        else
            set -l local_zip (__claude.export.pick "$since" $filename $sources)

            # claude.ai keeps the links behind a Cloudflare challenge that curl
            # can't pass, so the browser downloads them. It gives the file its
            # final name only once the download completes
            if test -z "$local_zip"
                echo "$prog: $filename ← browser, waiting up to $timeout"s
                set -l marker $dest/.opened
                touch $marker
                $opener $url >/dev/null 2>&1

                # A used link opens an error page instead of a download, so no
                # partial file shows up: .crdownload (Chromium), .download
                # (Safari), .part (Firefox)
                set -l started
                for i in (seq $timeout)
                    sleep 1
                    set local_zip (__claude.export.pick "$since" $filename $sources)
                    test -n "$local_zip"; and break

                    if test -z "$started"
                        set started (find $sources -maxdepth 1 -newer $marker \
                            \( -name '*.crdownload' -o -name '*.download' -o -name '*.part' \) 2>/dev/null)
                        test -z "$started" -a $i -ge 30; and break
                    end
                end

                rm -f $marker

                if test -z "$local_zip"
                    if test -z "$started"
                        echo "$prog: $filename download did not start, the link was used or has expired, request a new export" >&2
                    else
                        echo "$prog: $filename did not finish in $timeout"s", download it and rerun" >&2
                    end
                    set -a failed $filename
                    continue
                end
            end

            echo "$prog: $filename ← $local_zip"

            if not unzip -tq $local_zip >/dev/null 2>&1
                echo "$prog: $local_zip is not a valid zip" >&2
                set -a failed $filename
                continue
            end

            cp $local_zip $zip
        end

        if not unzip -oq $zip -d $dest/$category
            echo "$prog: unzip failed: $filename" >&2
            set -a failed $filename
            continue
        end

        set ok (math $ok + 1)
    end

    echo "$prog: $ok ok, "(count $failed)" failed → $dest"

    if test (count $failed) -gt 0
        printf '  failed: %s\n' $failed >&2
        return 1
    end
end

# Prints the newest finished download of $argv[2] from this export
function __claude.export.pick
    set -l since $argv[1]
    set -l filename $argv[2]
    set -l sources $argv[3..]

    # A browser renames a repeated download to "name (1).zip"
    set -l base (path change-extension '' $filename)
    set -l candidates $sources/$filename $sources/"$base ("*").zip"

    set -l fresh
    for file in (path filter -f $candidates)
        # Firefox creates the final name up front and fills name.part
        test -e $file.part; and continue

        # Every export names its zips the same, so one left from an older
        # export would pass for this one
        if test -z "$since"; or test (path mtime $file) -ge $since
            set -a fresh $file
        end
    end

    test -n "$fresh"; or return 1

    # Plain ls: an interactive ls is often an alias with its own -t
    command ls -t $fresh | head -n 1
end
