[Русская версия](README.ru.md)

![claude-export](.github/assets/banner.en.jpg)

# claude-export

Turns a claude.ai data export into a folder on your disk with one command: give it the manifest,
and it downloads every archive through your browser, checks it and unpacks it by category.

```sh
claude-export ~/Downloads/manifest-….json
```

## Why

claude.ai sends the export as a small JSON manifest with a link per archive. The links live for
24 hours, may work only once and sit behind a Cloudflare check that `curl` can't pass. So you end
up clicking eight links, waiting for each download and unpacking eight zips by hand, and one stray
click on a used link means asking for a new export.

`claude-export` does that round for you. It opens each link in your default browser, which passes
the check and is already signed in, waits until the download finishes and unpacks it. A link that
opens an error page instead of a download is reported within 30 seconds, not after a timeout.

## Requirements

- macOS or Linux with any POSIX `sh`
- [jq](https://jqlang.github.io/jq/), `unzip`, `find`
- a browser that saves downloads to a known folder

## Install

The CLI is a single file:

```sh
curl -fsSL https://raw.githubusercontent.com/aimuzov/claude-export/main/bin/claude-export \
	-o ~/.local/bin/claude-export && chmod +x ~/.local/bin/claude-export
```

Completions for fish:

```sh
curl -fsSL https://raw.githubusercontent.com/aimuzov/claude-export/main/completions/claude-export.fish \
	-o ~/.config/fish/completions/claude-export.fish
```

With [chezmoi](https://www.chezmoi.io/), in `.chezmoiexternal.toml`:

```toml
[".local/bin/claude-export"]
type = "file"
url = "https://raw.githubusercontent.com/aimuzov/claude-export/main/bin/claude-export"
executable = true
refreshPeriod = "168h"
```

## Usage

1. On claude.ai open Settings → Privacy → Export data and wait for the email.
2. Download the manifest from the email. Don't open the archive links yourself: each may work only
   once.
3. Run:

```sh
claude-export [-f dir]... [-t seconds] <manifest.json> [dest_root]
```

| Option | Meaning |
| --- | --- |
| `-f dir` | Folder the browser saves downloads to, repeatable. Default: the manifest's folder and `~/Downloads` |
| `-t seconds` | How long to wait for each download. Default: 300 |
| `dest_root` | Where backups go. Default: `$CLAUDE_EXPORT_DEST` or `~/claude-export` |

The result lands in `dest_root/<created_at>/`:

```
2026-10-29T08-57-58/
├── manifest.json        copy of the manifest
├── zips/                the archives as downloaded
├── conversations/       conversations.json
├── projects/
├── memories/
└── …                    one folder per category
```

## How it behaves

- **Archives already on disk are used as they are.** If the browser has already saved a zip, it is
  taken without opening the link. A zip older than the export's `created_at` is skipped: every
  export names its archives the same, and a leftover from last month would pass for this one.
- **A repeated download** saved as `name (1).zip` is found too, the newest one wins.
- **A used or expired link** opens an error page and no download starts. If no partial file
  (`.crdownload`, `.download` or `.part`) shows up within 30 seconds, the archive is reported and the
  rest go on.
- **One failure does not stop the rest**, since the links may die once opened. At the end you get
  a summary and exit code 1 if anything failed.
- **Reruns are safe.** Archives already in the backup are skipped, so you can download the missing
  ones by hand and run it again.

| Variable | Meaning |
| --- | --- |
| `CLAUDE_EXPORT_DEST` | Default `dest_root` |
| `CLAUDE_EXPORT_OPEN` | Command that opens a URL. Default: `open` on macOS, `xdg-open` elsewhere |

## Development

```sh
sh tests/run.sh
shellcheck -s sh bin/claude-export tests/run.sh
```

The tests run the CLI against fake manifests with a fake browser set through `CLAUDE_EXPORT_OPEN`.

## License

[MIT](LICENSE)
