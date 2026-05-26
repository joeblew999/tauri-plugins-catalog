#!/usr/bin/env nu
# examples:build <name> — read the entry from examples.jsonl, build it for
# every declared target the host can handle, report artifacts.
#
# Source: `local` (in-tree) preferred when set; else clone `repo` into work/.
# NDK_HOME: set from entry's android.ndk when specified, else default mise path.
#
# Usage: mise run examples:build <name>

const NDK_DEFAULT_PATH = "/Users/apple/.local/share/mise/installs/vfox-mise-plugins-vfox-android-sdk/20.0/ndk/27.0.12077973"

def main [name: string] {
    let entries = (open examples.jsonl --raw | lines | each { from json })
    let matches = ($entries | where name == $name)
    if ($matches | length) == 0 {
        print --stderr $"no examples.jsonl entry named: ($name)"
        exit 1
    }
    let entry = ($matches | first)

    print $"## ($entry.name)"
    print $"   ($entry.description)"
    print $"   targets: ($entry.targets | str join ', ')"
    print ""

    # Resolve build dir
    let work_dir = if $entry.local != null {
        print $"→ using in-tree path: ($entry.local)"
        $entry.local
    } else {
        let wd = $"work/($name)"
        if not ($wd | path exists) {
            mkdir work
            print $"→ cloning ($entry.repo) -> ($wd)"
            ^git clone $entry.repo $wd
        } else {
            print $"→ using existing clone at ($wd)"
            let r = (^git -C $wd pull --ff-only | complete)
        }
        $wd
    }

    let root = (pwd)
    cd $work_dir

    # npm install (most Tauri projects use a JS frontend)
    if ("package.json" | path exists) {
        print "→ npm install..."
        ^npm install --silent
    }

    let host = $nu.os-info.name
    mut built = []

    # Desktop build — only attempt if host can build it natively
    let desktop_target_for_host = if $host == "macos" { "macos" } else if $host == "linux" { "linux" } else { "windows" }
    if ($desktop_target_for_host in $entry.targets) {
        print ""
        print $"→ desktop build for host: ($host)..."
        let r = (^cargo tauri build | complete)
        if $r.exit_code == 0 {
            print "  ✓ desktop build succeeded"
            $built = ($built | append $"desktop ($host)")
        } else {
            print --stderr $"  ✗ desktop build failed (exit ($r.exit_code))"
        }
    }

    # Android build
    if ("android" in $entry.targets) {
        let ndk_home = if $entry.android.ndk != null {
            let candidate = $"($NDK_DEFAULT_PATH | path dirname)/($entry.android.ndk)"
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
            if not ("src-tauri/gen/android" | path exists) {
                let init_r = (^npm run tauri android init | complete)
                if $init_r.exit_code != 0 {
                    print --stderr "  ✗ android init failed"
                }
            }
            let r = (^npm run tauri android build -- --apk --debug | complete)
            if $r.exit_code == 0 {
                let apks = (glob "src-tauri/gen/android/app/build/outputs/apk/**/*.apk")
                if ($apks | length) > 0 {
                    print $"  ✓ android APK built: ($apks | first)"
                    $built = ($built | append "android APK")
                } else {
                    print "  ✓ android build returned 0 but no APK found"
                }
            } else {
                print --stderr $"  ✗ android build failed (exit ($r.exit_code))"
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
            $built = ($built | append "ios simulator")
        } else {
            print --stderr "  ✗ ios build failed (likely missing simulator runtime — see tauri:doctor:ios)"
        }
    }

    cd $root
    print ""
    if ($built | length) == 0 {
        print --stderr "no artifacts built."
        exit 1
    }
    print $"✓ built: ($built | str join ', ')"
}
