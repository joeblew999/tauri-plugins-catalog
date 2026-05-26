#!/usr/bin/env nu
# tauri:doctor — orchestrator. Runs base + Android + iOS sub-doctors.
#
# Each sub-doctor is also runnable standalone:
#   mise run tauri:doctor:base
#   mise run tauri:doctor:android
#   mise run tauri:doctor:ios
#
# iOS sub-doctor self-gates on macOS; skips cleanly on other hosts.

def run-sub [path: string] {
    let r = (^nu $path | complete)
    print $r.stdout
    if ($r.stderr | str trim) != "" { print --stderr $r.stderr }
    $r.exit_code
}

def main [] {
    mut fails = 0

    let base = (run-sub "scripts/tauri/doctor-base.nu")
    if $base != 0 { $fails = $fails + 1 }
    print ""

    let android = (run-sub "scripts/tauri/doctor-android.nu")
    if $android != 0 { $fails = $fails + 1 }
    print ""

    let ios = (run-sub "scripts/tauri/doctor-ios.nu")
    if $ios != 0 { $fails = $fails + 1 }
    print ""

    if $fails > 0 {
        print $"($fails) sub-doctor\(s\) reported failures."
        exit 1
    }
    print "All sub-doctors passed."
}
