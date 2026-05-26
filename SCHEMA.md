# plugins.jsonl schema

One JSON object per line. Field order is fixed so diffs stay readable.

| field           | type                                | notes                                                          |
| --------------- | ----------------------------------- | -------------------------------------------------------------- |
| `name`          | string                              | short slug, e.g. `fs`, `barcode-scanner`                       |
| `crate`         | string \| null                      | crates.io name, e.g. `tauri-plugin-fs`                         |
| `npm`           | string \| null                      | npm package, e.g. `@tauri-apps/plugin-fs`                      |
| `official`      | bool                                | maintained under `tauri-apps/`                                 |
| `description`   | string                              | one-line, ends in a period                                     |
| `repo`          | string (url)                        | canonical source repo                                          |
| `path`          | string \| null                      | subpath within `repo` if it's a monorepo                       |
| `platforms`     | object                              | keys: `windows` `macos` `linux` `ios` `android`                |
|                 |                                     | values: `"yes"` \| `"no"` \| `"unknown"`                       |
| `tags`          | string[]                            | short category tags, lowercase, kebab-case                     |
| `active_fork`   | string (url) \| null                | optional. set when `repo` is the canonical source but a fork carries meaningful recent work (security patches, fixes). consumers should prefer `active_fork` for installs but credit `repo` as the origin. |
| `last_verified` | string (`YYYY-MM-DD`)               | date the entry was last checked against upstream               |

## Conventions

- Tauri v1-only plugins are not listed — this catalog tracks v2.
- A plugin is considered "official" only if it lives under `github.com/tauri-apps/`.
- `description` is copied from upstream when one exists; otherwise written here.
- Append-only by default; re-sort with `mise run sort` before committing bulk edits.
