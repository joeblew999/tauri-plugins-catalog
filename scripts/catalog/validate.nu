#!/usr/bin/env nu
# Verify plugins.jsonl: every line parses and matches the shape of schema.nuon.

let schema = (open schema.nuon)
let required = ($schema | columns)
let platform_keys = ($schema.platforms | columns)
let valid_platform_values = ["yes" "no" "unknown"]

let raw = (open plugins.jsonl --raw)
let total = ($raw | lines | length)

let errors = ($raw | lines | enumerate | each { |row|
    let n = $row.index + 1
    let entry = try { $row.item | from json } catch { null }
    if $entry == null {
        $"line ($n): not valid JSON"
    } else {
        let cols = ($entry | columns)
        let missing = ($required | where { |k| not ($k in $cols) })
        if ($missing | length) > 0 {
            $"line ($n): missing fields: ($missing | str join ', ')"
        } else {
            let pcols = ($entry.platforms | columns)
            let missing_p = ($platform_keys | where { |k| not ($k in $pcols) })
            if ($missing_p | length) > 0 {
                $"line ($n): platforms missing keys: ($missing_p | str join ', ')"
            } else {
                let bad = ($platform_keys | where { |k|
                    not (($entry.platforms | get $k) in $valid_platform_values)
                })
                if ($bad | length) > 0 {
                    $"line ($n): bad platform values for: ($bad | str join ', ')"
                } else {
                    null
                }
            }
        }
    }
} | where { |x| $x != null })

if ($errors | length) > 0 {
    for e in $errors { print $e }
    print $"($errors | length) invalid line\(s\)"
    exit 1
}
print $"ok: ($total) entries match schema.nuon"
