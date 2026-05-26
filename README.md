# tauri-plugins-catalog

Structured catalog of Tauri v2 plugins as JSONL.

- [plugins.jsonl](plugins.jsonl) — one plugin per line
- [SCHEMA.md](SCHEMA.md) — field definitions

## Quick use

```sh
# count entries
jq -s 'length' plugins.jsonl

# list mobile-supporting plugins
jq -c 'select(.platforms.ios == "yes" or .platforms.android == "yes") | .name' plugins.jsonl

# all official plugin crate names
jq -r 'select(.official) | .crate' plugins.jsonl
```

## Tasks

```sh
mise run validate   # every line parses as JSON, required fields present
mise run count      # entry count + official/third-party split
mise run sort       # sort plugins.jsonl by name (in place)
```

## Sources

- Official: [tauri-apps/plugins-workspace](https://github.com/tauri-apps/plugins-workspace)
- Third-party: added on demand
