#!/usr/bin/env nu
# examples:coverage — for each plugin in plugins.jsonl, list which examples
# claim to demonstrate it via their `plugins` field. Highlight gaps.
#
# Usage: mise run examples:coverage

def main [] {
    let plugins = (open plugins.jsonl --raw | lines | each { from json })
    let examples = (open examples.jsonl --raw | lines | each { from json })

    # Build: plugin name -> [example names that claim it]
    let coverage = ($plugins | each { |p|
        let covering = ($examples | where { |e| $p.name in $e.plugins } | get name)
        {plugin: $p.name, official: $p.official, examples: $covering, covered: (($covering | length) > 0)}
    })

    print "## Plugin → Example coverage"
    print ""
    $coverage | each { |row|
        let mark = if $row.covered { "✓" } else { " " }
        let exs = if $row.covered { $row.examples | str join ", " } else { "(none)" }
        let kind = if $row.official { "official" } else { "third-party" }
        $"  [($mark)] ($row.plugin | fill -a left -w 20) ($kind | fill -a left -w 11) — ($exs)"
    } | each { |line| print $line } | ignore

    print ""
    let covered = ($coverage | where covered | length)
    let total = ($coverage | length)
    let uncovered = ($total - $covered)
    print $"## Summary"
    print $"  total plugins:  ($total)"
    print $"  covered:        ($covered)"
    print $"  uncovered:      ($uncovered)"
    print ""

    if $uncovered > 0 {
        print "## Uncovered plugins (no example demonstrates them)"
        let by_kind = ($coverage | where { |r| not $r.covered } | group-by official)
        for k in [true false] {
            let label = if $k { "official" } else { "third-party" }
            let names = ($by_kind | get -o ($k | into string) | default [] | get plugin)
            if ($names | length) > 0 {
                print $"  ($label):  ($names | str join ', ')"
            }
        }
    }
}
