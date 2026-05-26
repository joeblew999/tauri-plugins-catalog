#!/usr/bin/env nu
# tauri:doctor:base — checks every Tauri 2 project needs, no platform layers.
# Exits 0 if all green, 1 otherwise.

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
    mut fails = 0
    print "[Base]"

    ok "nushell" (version | get version)

    let r = (probe "mise" ["--version"])
    if $r.ok { ok "mise" $r.ver } else {
        fail "mise" "https://mise.jdx.dev/getting-started.html"
        $fails = $fails + 1
    }

    let r = (probe "rustc" ["--version"])
    if $r.ok { ok "rustc" $r.ver } else {
        fail "rustc" "mise use rust@stable  (Tauri 2 needs >= 1.77.2)"
        $fails = $fails + 1
    }

    let r = (probe "cargo" ["--version"])
    if $r.ok { ok "cargo" $r.ver } else {
        fail "cargo" "ships with rustc; reinstall the Rust toolchain"
        $fails = $fails + 1
    }

    let r = (probe "node" ["--version"])
    if $r.ok { ok "node" $r.ver } else {
        fail "node" "mise use node@lts"
        $fails = $fails + 1
    }

    let r = (probe "cargo" ["tauri" "--version"])
    if $r.ok { ok "tauri-cli" $r.ver } else {
        fail "tauri-cli" 'mise use "cargo:tauri-cli@^2"  (or npm:@tauri-apps/cli)'
        $fails = $fails + 1
    }

    let r = (probe "cargo-binstall" ["-V"])
    if $r.ok { ok "cargo-binstall" $r.ver } else {
        fail "cargo-binstall" "mise use -g cargo-binstall@latest  (prebuilt via aqua, fast)"
        $fails = $fails + 1
    }

    let os = $nu.os-info.name
    if $os == "macos" {
        let r = (probe "xcode-select" ["-p"])
        if $r.ok { ok "Xcode CLT" $r.ver } else {
            fail "Xcode CLT" "xcode-select --install"
            $fails = $fails + 1
        }
    } else if $os == "linux" {
        let pkg = (probe "pkg-config" ["--version"])
        if not $pkg.ok {
            fail "pkg-config" "apt install pkg-config  (or distro equivalent)"
            $fails = $fails + 1
        } else {
            let w41 = (^pkg-config --exists webkit2gtk-4.1 | complete).exit_code
            let w40 = (^pkg-config --exists webkit2gtk-4.0 | complete).exit_code
            if $w41 == 0 {
                ok "webkit2gtk" "4.1 (Ubuntu 24.04+)"
            } else if $w40 == 0 {
                ok "webkit2gtk" "4.0 (Ubuntu 22.04)"
            } else {
                fail "webkit2gtk" "apt install libwebkit2gtk-4.1-dev libsoup-3.0-dev librsvg2-dev"
                $fails = $fails + 1
            }
        }
    } else {
        print $"  [skip] OS webview deps — host is ($os), not macos/linux"
    }

    if $fails > 0 { exit 1 } else { exit 0 }
}
