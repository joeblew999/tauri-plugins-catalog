#!/usr/bin/env nu
# Substring search across name, description, tags.
# Usage: nu scripts/search.nu <term>

def main [term: string] {
    let q = ($term | str downcase)
    let plugins = (open plugins.jsonl --raw | lines | each { from json })
    let matches = ($plugins | where { |p| (
        ($p.name | str downcase | str contains $q) or
        ($p.description | str downcase | str contains $q) or
        ($p.tags | any { |t| ($t | str downcase | str contains $q) })
    )})
    if ($matches | length) == 0 {
        print $"no matches for: ($term)"
        exit 1
    }
    $matches | select name official description tags
}
