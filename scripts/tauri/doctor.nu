#!/usr/bin/env nu
# tauri:doctor — verify Tauri toolchain prerequisites.
#
# Layer 1 (base) always runs: rust, cargo, node, tauri-cli, cargo-binstall,
# OS webview deps.
#
# Layer 2 (Android) runs when src-tauri/gen/android/ exists in cwd, or when
# --android is passed. Checks: Java 17, ANDROID_HOME, sdkmanager, NDK_HOME,
# Rust Android targets.
#
# Exit 0 if all checks pass; 1 otherwise. Side-effect-free.

def ok [name: string, detail: string = ""] {
    let suffix = if $detail == "" { "" } else { $" — ($detail)" }
    print $"  [ok]   ($name)($suffix)"
}

def fail [name: string, hint: string] {
    print $"  [FAIL] ($name)"
    print $"         fix: ($hint)"
}

# Run an external command and capture stdout/stderr/exit_code.
# Returns {ok: bool, ver: string}. `ver` is the first line of stdout (or stderr
# if --stderr-version), trimmed.
def probe [cmd: string, args: list<string> = [], --stderr-version] {
    let r = (^$cmd ...$args | complete)
    if $r.exit_code != 0 {
        return {ok: false, ver: ""}
    }
    let raw = if $stderr_version { $r.stderr } else { $r.stdout }
    {ok: true, ver: ($raw | lines | first | default "" | str trim)}
}

def main [--android] {
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

    # OS-specific webview deps
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

    # Android section
    let android_project = ("src-tauri/gen/android" | path exists)
    let do_android = $android or $android_project

    print ""
    if not $do_android {
        print "[Android] skipped — pass --android, or cd to a project with src-tauri/gen/android/"
    } else {
        print "[Android]"

        let java_home = ($env.JAVA_HOME? | default "")
        if $java_home == "" {
            fail "JAVA_HOME" "mise use java@17  (sets JAVA_HOME automatically)"
            $fails = $fails + 1
        } else if not ($java_home | path exists) {
            fail "JAVA_HOME" $"set but does not exist: ($java_home)"
            $fails = $fails + 1
        } else {
            ok "JAVA_HOME" $java_home
            let jr = (probe "java" ["-version"] --stderr-version)
            if not $jr.ok or $jr.ver == "" {
                fail "java" "JAVA_HOME set but `java -version` failed"
                $fails = $fails + 1
            } else if not ($jr.ver | str contains '"17.') {
                fail "java version" $"want 17.x — got: ($jr.ver)"
                $fails = $fails + 1
            } else {
                ok "java" $jr.ver
            }
        }

        let ah = ($env.ANDROID_HOME? | default "")
        if $ah == "" {
            fail "ANDROID_HOME" 'mise use "asdf:mise-plugins/mise-android-sdk@latest"'
            $fails = $fails + 1
        } else if not ($ah | path exists) {
            fail "ANDROID_HOME" $"set but does not exist: ($ah)"
            $fails = $fails + 1
        } else {
            ok "ANDROID_HOME" $ah
            let sm = (probe "sdkmanager" ["--version"])
            if not $sm.ok {
                fail "sdkmanager" $"not working; expected at ($ah)/cmdline-tools/latest/bin"
                $fails = $fails + 1
            } else {
                ok "sdkmanager" $sm.ver
            }
        }

        let nh = ($env.NDK_HOME? | default "")
        if $nh == "" {
            fail "NDK_HOME" "sdkmanager 'ndk;<version>' then export NDK_HOME=<that path>"
            $fails = $fails + 1
        } else if not ($nh | path exists) {
            fail "NDK_HOME" $"set but does not exist: ($nh)"
            $fails = $fails + 1
        } else {
            ok "NDK_HOME" $nh
        }

        let ru = (probe "rustup" ["--version"])
        if not $ru.ok {
            fail "rustup" "needed for Android Rust targets"
            $fails = $fails + 1
        } else {
            let listed = (^rustup target list --installed | complete)
            if $listed.exit_code != 0 {
                fail "rustup target list" ($listed.stderr | str trim)
                $fails = $fails + 1
            } else {
                let installed = ($listed.stdout | lines)
                let needed = ["aarch64-linux-android" "armv7-linux-androideabi" "i686-linux-android" "x86_64-linux-android"]
                let missing = ($needed | where { |t| not ($t in $installed) })
                if ($missing | length) == 0 {
                    ok "rust android targets" "(4/4)"
                } else {
                    fail "rust android targets" $"missing: ($missing | str join ', '). fix: rustup target add ($missing | str join ' ')"
                    $fails = $fails + 1
                }
            }
        }
    }

    print ""
    if $fails == 0 {
        print "All checks passed."
        exit 0
    } else {
        print $"($fails) check\(s\) failed."
        exit 1
    }
}
