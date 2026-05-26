#!/usr/bin/env nu
# tauri:ios:uninstall — reverse what tauri:ios:setup installed.
#
# Removes (idempotent):
#   - CocoaPods via `brew uninstall cocoapods` (matches setup install path)
#   - Rust iOS targets via rustup
#
# Does NOT remove (manual):
#   - Xcode itself (App Store install — uninstall via App Store)
#   - Xcode Command Line Tools (`sudo rm -rf /Library/Developer/CommandLineTools`)
#   - Homebrew itself
#
# Usage: nu scripts/tauri/ios-uninstall.nu [--dry-run] [--yes]

def main [--dry-run, --yes] {
    if $nu.os-info.name != "macos" {
        print --stderr "✗ iOS uninstall is macOS-only."
        exit 1
    }

    let actions = [
        "brew uninstall cocoapods",
        "rustup target remove aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios",
    ]

    print "Will run:"
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

    if (which brew | is-empty) {
        print --stderr "⚠  brew not on PATH; cannot uninstall cocoapods. Skipping."
    } else {
        # `brew uninstall` exits nonzero if not installed; suppress with complete.
        let r = (^brew uninstall cocoapods | complete)
        if $r.exit_code == 0 {
            print "  ✓ cocoapods removed via brew"
        } else {
            print $"  (cocoapods not installed via brew — skipping)"
        }
    }

    if (which rustup | is-empty) {
        print --stderr "⚠  rustup not on PATH; skipping Rust target removal."
    } else {
        ^rustup target remove aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
    }

    print ""
    print "✓ Uninstall complete."
    print "  Xcode CLT (manual): xcode-select --reset or sudo rm -rf /Library/Developer/CommandLineTools"
    print "  Xcode itself: remove via App Store."
}
