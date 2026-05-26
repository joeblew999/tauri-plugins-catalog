#!/usr/bin/env nu
# Lint: fail if any of our source files contain hardcoded OS-specific
# absolute paths. Pure nushell (works on Mac, Linux, Windows).
#
# Allow-listed: /Library/Developer/CommandLineTools (Apple's fixed location,
# only mentioned inside macOS-gated ios-uninstall.nu).

const PATTERNS = ["/Users/" "/opt/homebrew" "darwin-x86_64" "darwin-aarch64"]
const ALLOW_LINE_CONTAINS = ["/Library/Developer/CommandLineTools"]

def main [] {
    let files = (
        (glob "scripts/**/*.nu")
        | append ["plugins.jsonl" "examples.jsonl" "schema.nuon" "example.schema.nuon"]
        | where { |p| ($p | path exists) and (($p | path basename) != "lint-os-paths.nu") }
    )

    let hits = ($files | each { |f|
        let content = (open $f --raw)
        $content | lines | enumerate | each { |row|
            let line = $row.item
            let has_bad = ($PATTERNS | any { |p| $line | str contains $p })
            let allowed = ($ALLOW_LINE_CONTAINS | any { |a| $line | str contains $a })
            if $has_bad and (not $allowed) {
                $"($f):(($row.index) + 1): ($line | str trim)"
            } else { null }
        } | where { |x| $x != null }
    } | flatten)

    if ($hits | length) > 0 {
        print --stderr "Hardcoded OS-specific paths detected:"
        for h in $hits { print --stderr $"  ($h)" }
        print --stderr ""
        print --stderr "Nushell is OS-neutral. Derive paths from $env vars or install state, not literals."
        exit 1
    }
    print $"ok: ($files | length) files checked, no hardcoded host paths"
}
