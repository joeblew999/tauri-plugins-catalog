#!/usr/bin/env nu
# tauri:doctor:android — Android-specific prereq checks.
# Runs on any desktop host (Android NDK from any desktop is the standard flow).

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
    print "[Android]"

    let java_home = ($env.JAVA_HOME? | default "")
    if $java_home == "" {
        fail "JAVA_HOME" "mise use -g java@17  (sets JAVA_HOME automatically)"
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
        fail "ANDROID_HOME" 'mise use -g vfox:mise-plugins/vfox-android-sdk@20.0  (no Studio; auto-sets ANDROID_HOME)'
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
        let ah = ($env.ANDROID_HOME? | default "")
        let ndk_dir = $"($ah)/ndk"
        if ($ah != "") and ($ndk_dir | path exists) and ((ls $ndk_dir | length) > 0) {
            let latest = (ls $ndk_dir | get name | each { |p| $p | path basename } | sort | last)
            fail "NDK_HOME" $"NDK installed at ($ndk_dir)/($latest); export NDK_HOME=($ndk_dir)/($latest)  -- or add to mise.toml [env]"
        } else {
            fail "NDK_HOME" "run `mise run tauri:android:setup` to install NDK + Rust targets"
        }
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

    if $fails > 0 { exit 1 } else { exit 0 }
}
