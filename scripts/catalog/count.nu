#!/usr/bin/env nu
# Entry count + official / third-party split.

let entries = (open plugins.jsonl --raw | lines | each { from json })
let total = ($entries | length)
let official = ($entries | where official | length)
let third = ($total - $official)

print $"total:       ($total)"
print $"official:    ($official)"
print $"third-party: ($third)"
