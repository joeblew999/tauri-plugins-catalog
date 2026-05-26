#!/usr/bin/env nu
# Verify examples.jsonl: every line parses and matches the shape of example.schema.nuon.

let schema = (open example.schema.nuon)
let required = ($schema | columns)
let valid_targets = ["windows" "macos" "linux" "ios" "android"]
let valid_tauri = ["1" "2"]

let raw = (open examples.jsonl --raw)
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
        } else if not ($entry.tauri_version in $valid_tauri) {
            $"line ($n): tauri_version must be one of: ($valid_tauri | str join ', '); got ($entry.tauri_version)"
        } else {
            let bad_t = ($entry.targets | where { |t| not ($t in $valid_targets) })
            if ($bad_t | length) > 0 {
                $"line ($n): bad target(s): ($bad_t | str join ', '). valid: ($valid_targets | str join ', ')"
            } else if ("android" in $entry.targets) and ($entry.android == null) {
                $"line ($n): targets includes 'android' but android field is null. Populate with { min_api, target_api, ndk }"
            } else if ("ios" in $entry.targets) and ($entry.ios == null) {
                $"line ($n): targets includes 'ios' but ios field is null. Populate with { deployment_target, xcode_min }"
            } else {
                null
            }
        }
    }
} | where { |x| $x != null })

if ($errors | length) > 0 {
    for e in $errors { print $e }
    print $"($errors | length) invalid line\(s\)"
    exit 1
}
print $"ok: ($total) entries match example.schema.nuon"
