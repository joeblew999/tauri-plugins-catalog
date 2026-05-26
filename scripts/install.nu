#!/usr/bin/env nu
# Print install snippets for a plugin, respecting active_fork.
# Usage: nu scripts/install.nu <name>

def main [name: string] {
    let plugins = (open plugins.jsonl --raw | lines | each { from json })
    let matches = ($plugins | where name == $name)
    if ($matches | length) == 0 {
        print $"no plugin named: ($name)"
        print "try: mise run search <term>"
        exit 1
    }
    let p = ($matches | first)
    let fork = ($p.active_fork? | default null)

    print $"# ($p.name) — ($p.description)"
    print $"# source: ($p.repo)"
    if $fork != null {
        print $"# active fork: ($fork) — carries recent fixes / security patches"
    }
    print ""

    if $p.official {
        # tauri-apps publishes to crates.io and npm under @tauri-apps/
        print "# Cargo.toml"
        print $"($p.crate) = \"2\""
        print ""
        print "# package.json"
        print $"\"($p.npm)\": \"^2\""
    } else {
        # Third-party: install directly from git
        let url = (if $fork != null { $fork } else { $p.repo })
        if $fork != null {
            print "# Cargo.toml — install from active fork"
        } else {
            print "# Cargo.toml"
        }
        print $"($p.crate) = { git = \"($url)\", package = \"($p.crate)\" }"
        print ""
        if ($p.npm? | default null) != null {
            print "# package.json — requires .npmrc configured for GitHub Packages"
            print $"\"($p.npm)\": \"*\""
        }
    }
}
