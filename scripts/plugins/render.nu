#!/usr/bin/env nu
# Regenerate the plugin table in README.md from plugins.jsonl.
# Plugins are grouped by category (Cross-platform / Desktop / Mobile).

def symbol [v: string] {
    if $v == "yes" { "✅" } else if $v == "no" { "❌" } else { "?" }
}

def org_from_url [url: string] {
    $url | parse "https://github.com/{org}/{repo}" | get org.0
}

# "[org](repo-url)", or "[origin](url) → [fork](url)" when active_fork is set.
def source_cell [entry: record] {
    let origin = $"[(org_from_url $entry.repo)]\(($entry.repo)\)"
    if $entry.active_fork == null {
        $origin
    } else {
        $"($origin) → [(org_from_url $entry.active_fork)]\(($entry.active_fork)\)"
    }
}

# Bucket a plugin into Cross-platform / Desktop / Mobile based on platform support.
def category [p: record] {
    let desktop_full = ($p.platforms.windows == "yes" and $p.platforms.macos == "yes" and $p.platforms.linux == "yes")
    let mobile_full = ($p.platforms.ios == "yes" and $p.platforms.android == "yes")
    let mobile_any = ($p.platforms.ios == "yes" or $p.platforms.android == "yes")
    if $desktop_full and $mobile_full {
        "Cross-platform"
    } else if $mobile_any and (not $desktop_full) {
        "Mobile"
    } else {
        "Desktop"
    }
}

def render_row [e: record] {
    let link = if $e.path == null { $e.repo } else { $"($e.repo)/tree/HEAD/($e.path)" }
    let src  = (source_cell $e)
    let win  = (symbol $e.platforms.windows)
    let mac  = (symbol $e.platforms.macos)
    let lin  = (symbol $e.platforms.linux)
    let ios  = (symbol $e.platforms.ios)
    let andr = (symbol $e.platforms.android)
    $"| [($e.name)]\(($link)\) | ($src) | ($e.description) | ($win) | ($mac) | ($lin) | ($ios) | ($andr) |"
}

def render_section [title: string, entries: list] {
    let header = ("| Plugin | Source | Description | Win | Mac | Lin | iOS | Android |\n" +
                  "| ------ | ------ | ----------- | :-: | :-: | :-: | :-: | :-----: |")
    let rows = ($entries | each { |e| render_row $e } | str join "\n")
    $"### ($title) \(($entries | length)\)\n\n($header)\n($rows)"
}

let entries = (
    open plugins.jsonl --raw | lines | each { from json } | sort-by name
    | each { |e| $e | upsert _cat (category $e) }
)

# Render in fixed category order; skip empty buckets.
let order = ["Cross-platform" "Desktop" "Mobile"]
let sections = (
    $order | each { |cat|
        let rows = ($entries | where _cat == $cat)
        if ($rows | length) == 0 { null } else { render_section $cat $rows }
    } | where { |s| $s != null } | str join "\n\n"
)

let begin = "<!-- BEGIN:plugins -->"
let end_marker = "<!-- END:plugins -->"
let readme = (open README.md --raw)

let p1 = ($readme | split row $begin)
if ($p1 | length) != 2 {
    error make { msg: $"BEGIN marker not found in README.md: ($begin)" }
}
let p2 = ($p1 | get 1 | split row $end_marker)
if ($p2 | length) != 2 {
    error make { msg: $"END marker not found in README.md: ($end_marker)" }
}

let new_readme = $"($p1 | get 0)($begin)\n($sections)\n($end_marker)($p2 | get 1)"
$new_readme | save -f README.md

print $"rendered ($entries | length) plugins in ($order | length) categories"
