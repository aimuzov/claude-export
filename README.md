<p align="center">
	<img src="https://img.shields.io/badge/English-d97757?logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA2MCAzMCI+PGNsaXBQYXRoIGlkPSJ0Ij48cGF0aCBkPSJNMzAsMTVoMzB2MTV6djE1aC0zMHpoLTMwdi0xNXp2LTE1aDMweiIvPjwvY2xpcFBhdGg+PHBhdGggZD0iTTAsMHYzMGg2MHYtMzB6IiBmaWxsPSIjMDEyMTY5Ii8+PHBhdGggZD0iTTAsMCA2MCwzME02MCwwIDAsMzAiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSI2Ii8+PHBhdGggZD0iTTAsMCA2MCwzME02MCwwIDAsMzAiIGNsaXAtcGF0aD0idXJsKCN0KSIgc3Ryb2tlPSIjQzgxMDJFIiBzdHJva2Utd2lkdGg9IjQiLz48cGF0aCBkPSJNMzAsMHYzME0wLDE1aDYwIiBzdHJva2U9IiNmZmYiIHN0cm9rZS13aWR0aD0iMTAiLz48cGF0aCBkPSJNMzAsMHYzME0wLDE1aDYwIiBzdHJva2U9IiNDODEwMkUiIHN0cm9rZS13aWR0aD0iNiIvPjwvc3ZnPg==" alt="English">
	<a href="README.ru.md"><img src="https://img.shields.io/badge/%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9-555?logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA5IDYiPjxwYXRoIGZpbGw9IiNmZmYiIGQ9Ik0wIDBoOXYzSDB6Ii8+PHBhdGggZmlsbD0iIzAwMzlhNiIgZD0iTTAgMmg5djJIMHoiLz48cGF0aCBmaWxsPSIjZDUyYjFlIiBkPSJNMCA0aDl2MkgweiIvPjwvc3ZnPg==" alt="Русский"></a>
</p>

<p align="center">
	<a href="https://github.com/aimuzov/claude-export"><img src=".github/assets/banner.en.jpg" alt="claude-export: a claude.ai data export in one command" width="100%"></a>
</p>

<p align="center">
	<a href="https://github.com/aimuzov/claude-export/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/aimuzov/claude-export/ci.yml?branch=main&label=ci" alt="CI"></a>
	<a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-d97757" alt="License: MIT"></a>
</p>

<h3 align="center">Your claude.ai data export, unpacked in one command</h3>
<p align="center">Give it the manifest, and it downloads every archive through your browser, checks it and unpacks it by category</p>

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
