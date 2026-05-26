#!/usr/bin/env nu
# tauri:ios:uninstall — remove what tauri:ios:setup installed.
#
# Removes (idempotent):
#   - CocoaPods gem (best-effort; depends on which gem env)
#   - Rust targets: aarch64-apple-ios, aarch64-apple-ios-sim, x86_64-apple-ios
#
# Does NOT remove (manual):
#   - Xcode itself (App Store install — uninstall via App Store)
#   - Xcode Command Line Tools (`sudo rm -rf /Library/Developer/CommandLineTools`)
#   - Ruby (mise-managed via per-task tools pin; auto-cleans when task not run)
#
# Usage: nu scripts/tauri/ios-uninstall.nu [--dry-run] [--yes]

def main [--dry-run, --yes] {
    if (sys host | get name) != "Darwin" {
        print --stderr "✗ iOS uninstall is macOS-only."
        exit 1
    }

    let actions = [
        "gem uninstall cocoapods --all --executables",
        "rustup target remove aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios",
    ]

    print "Will remove:"
    for a in $actions { print $"  - ($a)" }
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

    if (which gem | is-empty) {
        print --stderr "⚠  gem not on PATH; skipping cocoapods removal."
    } else {
        ^gem uninstall cocoapods --all --executables --ignore-dependencies
    }

    if (which rustup | is-empty) {
        print --stderr "⚠  rustup not on PATH; skipping Rust target removal."
    } else {
        ^rustup target remove aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
    }

    print ""
    print "✓ Uninstall complete."
    print "  Xcode CLT (manual): xcode-select --reset; or sudo rm -rf /Library/Developer/CommandLineTools"
    print "  Xcode itself: remove via App Store."
}
