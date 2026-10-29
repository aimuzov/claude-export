[English version](README.md)

![claude-export](.github/assets/banner.jpg)

# claude-export

Превращает экспорт данных claude.ai в папку на диске одной командой: даёшь ей манифест, а она
скачивает через браузер каждый архив, проверяет его и раскладывает по категориям.

```sh
claude-export ~/Downloads/manifest-….json
```

## Зачем

claude.ai присылает экспорт как маленький JSON-манифест со ссылкой на каждый архив. Ссылки живут
24 часа, могут сработать только один раз и закрыты проверкой Cloudflare, через которую `curl` не
проходит. В итоге кликаешь восемь ссылок, ждёшь каждую загрузку и руками распаковываешь восемь zip,
а один лишний клик по уже использованной ссылке означает новый запрос экспорта.

`claude-export` делает этот круг за тебя. Он открывает каждую ссылку в браузере по умолчанию,
который проходит проверку и уже залогинен, ждёт конца загрузки и распаковывает архив. Ссылку,
которая вместо загрузки открыла страницу с ошибкой, он отметит за 30 секунд, а не по таймауту.

## Что нужно

- macOS или Linux с любым POSIX `sh`
- [jq](https://jqlang.github.io/jq/), `unzip`, `find`
- браузер, который сохраняет загрузки в известную папку

## Установка

CLI -- это один файл:

```sh
curl -fsSL https://raw.githubusercontent.com/aimuzov/claude-export/main/bin/claude-export \
	-o ~/.local/bin/claude-export && chmod +x ~/.local/bin/claude-export
```

Автодополнение для fish:

```sh
curl -fsSL https://raw.githubusercontent.com/aimuzov/claude-export/main/completions/claude-export.fish \
	-o ~/.config/fish/completions/claude-export.fish
```

Через [chezmoi](https://www.chezmoi.io/), в `.chezmoiexternal.toml`:

```toml
[".local/bin/claude-export"]
type = "file"
url = "https://raw.githubusercontent.com/aimuzov/claude-export/main/bin/claude-export"
executable = true
refreshPeriod = "168h"
```

## Как пользоваться

1. На claude.ai открой Settings → Privacy → Export data и дождись письма.
2. Скачай из письма манифест. Ссылки на архивы сам не открывай: каждая может сработать только раз.
3. Запусти:

```sh
claude-export [-f dir]... [-t seconds] <manifest.json> [dest_root]
```

| Опция | Что значит |
| --- | --- |
| `-f dir` | Папка, куда браузер сохраняет загрузки, можно несколько. По умолчанию папка манифеста и `~/Downloads` |
| `-t seconds` | Сколько ждать каждую загрузку. По умолчанию 300 |
| `dest_root` | Куда класть бэкапы. По умолчанию `$CLAUDE_EXPORT_DEST` или `~/claude-export` |

Результат окажется в `dest_root/<created_at>/`:

```
2026-10-29T08-57-58/
├── manifest.json        копия манифеста
├── zips/                архивы как скачались
├── conversations/       conversations.json
├── projects/
├── memories/
└── …                    по папке на категорию
```

## Как он себя ведёт

- **Архивы, которые уже на диске, берутся как есть.** Если браузер уже сохранил zip, ссылка не
  открывается. Zip старше `created_at` экспорта пропускается: в каждом экспорте архивы называются
  одинаково, и остаток с прошлого месяца сошёл бы за этот.
- **Повторная загрузка** с именем `name (1).zip` тоже находится, берётся самая свежая.
- **Использованная или истёкшая ссылка** открывает страницу с ошибкой, и загрузка не начинается.
  Если за 30 секунд не появился незаконченный файл (`.crdownload`, `.download` или `.part`), архив
  отмечается как ошибка, а остальные качаются дальше.
- **Одна ошибка не останавливает остальные**, потому что ссылки могут умереть после открытия. В
  конце -- сводка и код выхода 1, если что-то не скачалось.
- **Перезапуск безопасен.** Архивы, которые уже в бэкапе, пропускаются, так что можно докачать
  недостающие руками и запустить снова.

| Переменная | Что значит |
| --- | --- |
| `CLAUDE_EXPORT_DEST` | `dest_root` по умолчанию |
| `CLAUDE_EXPORT_OPEN` | Команда, которая открывает URL. По умолчанию `open` на macOS, `xdg-open` в остальных |

## Разработка

```sh
sh tests/run.sh
shellcheck -s sh bin/claude-export tests/run.sh
```

Тесты гоняют CLI на фейковых манифестах с фейковым браузером через `CLAUDE_EXPORT_OPEN`.

## Лицензия

[MIT](LICENSE)
