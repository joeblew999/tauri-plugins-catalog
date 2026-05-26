#!/usr/bin/env nu
# tauri:android:uninstall — remove the SDK components and Rust targets that
# tauri:android:setup installed.
#
# Removes (idempotent — sdkmanager and rustup are no-ops if not present):
#   - NDK 27.0.12077973
#   - platforms;android-34
#   - build-tools;34.0.0
#   - Rust targets: aarch64/armv7/i686/x86_64-linux-android
#
# Does NOT remove (manual):
#   - Android Studio app (whatever installed ANDROID_HOME in the first place)
#   - The ANDROID_HOME directory itself
#   - Java (mise-managed; edit mise.toml or run: mise uninstall java@<ver>)
#
# Usage: nu scripts/tauri/android-uninstall.nu [--dry-run] [--yes]

def main [--dry-run, --yes] {
    let ah = ($env.ANDROID_HOME? | default "")
    if $ah == "" {
        print "ANDROID_HOME not set — nothing to uninstall."
        exit 0
    }

    let sdkmgr = $"($ah)/cmdline-tools/latest/bin/sdkmanager"

    let actions = [
        {label: $"sdkmanager --uninstall 'ndk;27.0.12077973'",       fn: "ndk"},
        {label: $"sdkmanager --uninstall 'platforms;android-34'",    fn: "platforms"},
        {label: $"sdkmanager --uninstall 'build-tools;34.0.0'",      fn: "build-tools"},
        {label: "rustup target remove aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android", fn: "rust"},
    ]

    print "Will remove:"
    for a in $actions { print $"  - ($a.label)" }
    print ""

    if $dry_run {
        print "(dry-run; nothing executed)"
        exit 0
    }

    if not $yes {
        let resp = (input "Proceed? [y/N] ")
        if ($resp | str downcase) != "y" {
            print "aborted."
            exit 0
        }
    }

    if not ($sdkmgr | path exists) {
        print --stderr $"⚠  sdkmanager not at ($sdkmgr); skipping SDK component uninstalls."
    } else {
        ^$sdkmgr --uninstall "ndk;27.0.12077973"
        ^$sdkmgr --uninstall "platforms;android-34"
        ^$sdkmgr --uninstall "build-tools;34.0.0"
    }

    if (which rustup | is-empty) {
        print --stderr "⚠  rustup not on PATH; skipping Rust target removal."
    } else {
        ^rustup target remove aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
    }

    print ""
    print "✓ Uninstall complete."
    print $"  ANDROID_HOME ($ah) still exists — delete manually if you also want to remove Android Studio's SDK."
    print "  Java is mise-managed: edit your mise.toml or run `mise uninstall java@<ver>`."
}
