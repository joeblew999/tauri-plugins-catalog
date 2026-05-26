#!/usr/bin/env nu
# Check entries against upstream pushed_at and detect drift.
# Requires the `gh` CLI to be authenticated.

def repo_slug [url: string] {
    let parts = ($url | parse "https://github.com/{owner}/{repo}" | first)
    $"($parts.owner)/($parts.repo)"
}

def date_only [iso: string] {
    $iso | str substring 0..9
}

let plugins = (open plugins.jsonl --raw | lines | each { from json })

# Gather unique repo URLs across .repo and .active_fork.
let repos = ($plugins | each { |p|
    [$p.repo (($p.active_fork? | default null))]
} | flatten | where { |x| $x != null } | uniq)

print $"fetching pushed_at for ($repos | length) unique repos..."
let pushed = ($repos | each { |url|
    let slug = (repo_slug $url)
    let ts = (gh api $"repos/($slug)" --jq '.pushed_at' | str trim)
    {url: $url, slug: $slug, pushed_at: $ts}
})

# Index by url for fast lookup.
let pushed_by_url = ($pushed | reduce --fold {} { |row, acc|
    $acc | upsert $row.url $row.pushed_at
})

# Per-entry freshness check.
let report = ($plugins | each { |p|
    let repo_pushed = ($pushed_by_url | get $p.repo)
    let fork = ($p.active_fork? | default null)
    let fork_pushed = (if $fork != null { $pushed_by_url | get $fork } else { null })
    let lv = ($p.last_verified | into datetime)
    let rp = ($repo_pushed | into datetime)
    let stale = ($lv < $rp)
    let fork_newer = (if $fork_pushed != null {
        $lv < ($fork_pushed | into datetime)
    } else { false })
    {
        name: $p.name
        last_verified: $p.last_verified
        repo_pushed: (date_only $repo_pushed)
        fork_pushed: (if $fork_pushed != null { date_only $fork_pushed } else { "" })
        status: (if $stale or $fork_newer { "STALE" } else { "ok" })
    }
})

print ""
print "=== entry freshness ==="
print ($report | table --expand)

let stale_count = ($report | where status == "STALE" | length)
let noun = if $stale_count == 1 { "entry" } else { "entries" }
print ""
print $"($stale_count) ($noun) need re-verification"

# Detect official plugins upstream that we don't list.
print ""
print "=== drift: new tauri-apps plugins not in catalog ==="
let upstream = (
    gh api repos/tauri-apps/plugins-workspace/contents/plugins --jq '[.[] | select(.type=="dir") | .name]'
    | from json
)
let known = ($plugins | where official | get name)
let missing = ($upstream | where { |x| not ($x in $known) })
if ($missing | length) == 0 {
    print "(none — catalog covers all upstream official plugins)"
} else {
    for n in $missing { print $"  + ($n)" }
}
