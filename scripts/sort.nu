#!/usr/bin/env nu
# Sort plugins.jsonl by name, in place. Preserves field order per entry.

let sorted = (open plugins.jsonl --raw | lines | each { from json } | sort-by name)
let out = (($sorted | each { to json --raw }) | str join "\n") + "\n"
$out | save -f plugins.jsonl
print $"sorted ($sorted | length) entries"
