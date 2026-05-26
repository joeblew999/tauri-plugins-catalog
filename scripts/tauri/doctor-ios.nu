#!/usr/bin/env nu
# tauri:doctor:ios — iOS-specific prereq checks. macOS host only.
# Returns 0 silently on non-macOS (skip message) since iOS dev requires Apple's tooling.

def ok [name: string, detail: string = ""] {
    let suffix = if $detail == "" { "" } else { $" — ($detail)" }
    print $"  [ok]   ($name)($suffix)"
}
def fail [name: string, hint: string] {
    print $"  [FAIL] ($name)"
    print $"         fix: ($hint)"
}
def probe [cmd: string, args: list<string> = [], --stderr-version] {
    if (which $cmd | is-empty) { return {ok: false, ver: ""} }
    let r = (^$cmd ...$args | complete)
    if $r.exit_code != 0 { return {ok: false, ver: ""} }
    let raw = if $stderr_version { $r.stderr } else { $r.stdout }
    {ok: true, ver: ($raw | lines | first | default "" | str trim)}
}

def main [] {
    if $nu.os-info.name != "macos" {
        print $"[iOS] skipped — requires macOS host (got ($nu.os-info.name))"
        exit 0
    }

    mut fails = 0
    print "[iOS]"

    let xc = (probe "xcode-select" ["-p"])
    if not $xc.ok {
        fail "Xcode" "xcode-select --install  (or install Xcode from App Store)"
        $fails = $fails + 1
    } else {
        ok "xcode-select" $xc.ver
        if ($xc.ver | str contains "CommandLineTools") {
            fail "Xcode" "CLT only — iOS simulator builds need full Xcode. App Store → Xcode, then: sudo xcode-select -s /Applications/Xcode.app"
            $fails = $fails + 1
        } else {
            ok "Xcode" "full install"
        }
    }

    let pod = (probe "pod" ["--version"])
    if not $pod.ok {
        fail "CocoaPods" "run `mise run tauri:ios:setup` to install"
        $fails = $fails + 1
    } else {
        ok "pod (CocoaPods)" $pod.ver
    }

    let ru = (probe "rustup" ["--version"])
    if not $ru.ok {
        fail "rustup" "needed for Rust iOS targets"
        $fails = $fails + 1
    } else {
        let listed = (^rustup target list --installed | complete)
        if $listed.exit_code != 0 {
            fail "rustup target list" ($listed.stderr | str trim)
            $fails = $fails + 1
        } else {
            let installed = ($listed.stdout | lines)
            let needed = ["aarch64-apple-ios" "aarch64-apple-ios-sim" "x86_64-apple-ios"]
            let missing = ($needed | where { |t| not ($t in $installed) })
            if ($missing | length) == 0 {
                ok "rust ios targets" "(3/3)"
            } else {
                fail "rust ios targets" $"missing: ($missing | str join ', '). fix: rustup target add ($missing | str join ' ')"
                $fails = $fails + 1
            }
        }
    }

    if $fails > 0 { exit 1 } else { exit 0 }
}
