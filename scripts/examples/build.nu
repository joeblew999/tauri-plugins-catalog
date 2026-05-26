#!/usr/bin/env nu
# examples:build <name> — clone the named entry from examples.jsonl and build
# it for every platform the entry declares it targets (matching host capability).
#
# Reads examples.jsonl. Clones into ./work/<name>/ (gitignored). Sets NDK_HOME
# from the entry's android.ndk if specified (else relies on doctor's reported
# install path).
#
# Usage: nu scripts/examples/build.nu <name>

const NDK_DEFAULT_PATH = "/Users/apple/.local/share/mise/installs/vfox-mise-plugins-vfox-android-sdk/20.0/ndk/27.0.12077973"

def main [name: string] {
    let entries = (open examples.jsonl --raw | lines | each { from json })
    let matches = ($entries | where name == $name)
    if ($matches | length) == 0 {
        print --stderr $"no examples.jsonl entry named: ($name)"
        print --stderr "try: mise run examples:validate (then check examples.jsonl)"
        exit 1
    }
    let entry = ($matches | first)

    print $"## ($entry.name)"
    print $"   ($entry.description)"
    print $"   targets: ($entry.targets | str join ', ')"
    print ""

    let work_dir = $"work/($name)"
    if not ($work_dir | path exists) {
        mkdir work
        print $"→ cloning ($entry.repo) -> ($work_dir)"
        ^git clone $entry.repo $work_dir
    } else {
        print $"→ using existing checkout at ($work_dir)"
        let root = (pwd)
    cd $work_dir
        let r = (^git -C $work_dir pull --ff-only | complete)
    }

    let root = (pwd)
    cd $work_dir

    # npm install (most Tauri projects use a JS frontend)
    if ("package.json" | path exists) {
        print "→ npm install..."
        ^npm install --silent
    }

    let host = $nu.os-info.name
    mut built_artifacts = []

    # Desktop build — only attempt if host can build for it natively
    let desktop_target_for_host = if $host == "macos" { "macos" } else if $host == "linux" { "linux" } else { "windows" }
    if ($desktop_target_for_host in $entry.targets) {
        print ""
        print $"→ desktop build for host: ($host)..."
        let r = (^cargo tauri build | complete)
        if $r.exit_code == 0 {
            print $"  ✓ desktop build succeeded"
            $built_artifacts = ($built_artifacts | append $"desktop ($host)")
        } else {
            print --stderr $"  ✗ desktop build failed (exit ($r.exit_code))"
        }
    }

    # Android build
    if ("android" in $entry.targets) {
        # NDK_HOME: prefer entry's pinned ndk if specified, else default mise install path
        let ndk = if $entry.android.ndk != null { $entry.android.ndk } else { null }
        let ndk_home = if $ndk != null {
            # try common locations matching the ndk version
            let candidate = $"($NDK_DEFAULT_PATH | path dirname)/($ndk)"
            if ($candidate | path exists) { $candidate } else { $NDK_DEFAULT_PATH }
        } else {
            $NDK_DEFAULT_PATH
        }
        if not ($ndk_home | path exists) {
            print --stderr $"  ✗ NDK not found at ($ndk_home). Run: mise run tauri:android:setup"
        } else {
            $env.NDK_HOME = $ndk_home
            print ""
            print $"→ android build with NDK_HOME=($ndk_home)..."

            # init if not already done
            if not ("src-tauri/gen/android" | path exists) {
                let init_r = (^npm run tauri android init | complete)
                if $init_r.exit_code != 0 {
                    print --stderr "  ✗ android init failed"
                    print --stderr $init_r.stderr
                }
            }

            let r = (^npm run tauri android build -- --apk --debug | complete)
            if $r.exit_code == 0 {
                let apk_glob = "src-tauri/gen/android/app/build/outputs/apk/**/*.apk"
                let apks = (glob $apk_glob)
                if ($apks | length) > 0 {
                    print $"  ✓ android APK built: ($apks | first)"
                    $built_artifacts = ($built_artifacts | append "android APK")
                } else {
                    print "  ✓ android build returned 0 but no APK found"
                }
            } else {
                print --stderr $"  ✗ android build failed (exit ($r.exit_code))"
                let tail_lines = ($r.stderr | lines | reverse | first 5 | reverse | str join "\n")
                print --stderr $tail_lines
            }
        }
    }

    # iOS build (macOS host only)
    if ("ios" in $entry.targets) and $host == "macos" {
        print ""
        print "→ ios build (simulator)..."
        if not ("src-tauri/gen/apple" | path exists) {
            let init_r = (^npm run tauri ios init | complete)
            if $init_r.exit_code != 0 {
                print --stderr "  ✗ ios init failed"
            }
        }
        let r = (^npm run tauri ios build -- --target aarch64-sim --debug | complete)
        if $r.exit_code == 0 {
            print "  ✓ ios sim build succeeded"
            $built_artifacts = ($built_artifacts | append "ios simulator")
        } else {
            print --stderr "  ✗ ios build failed (likely missing simulator runtime — see tauri:doctor:ios)"
        }
    }

    cd $root
    print ""
    if ($built_artifacts | length) == 0 {
        print --stderr "no artifacts built."
        exit 1
    }
    print $"✓ built: ($built_artifacts | str join ', ')"
}
