#!/usr/bin/env nu
# tauri:ios:setup — install + verify iOS tooling for Tauri development.
# macOS host only (iOS requires Apple's tooling).
#
# CocoaPods install: Homebrew. Tried mise gem backends first
# (`mise use cocoapods@X` and the `ronnnnn/asdf-cocoapods` plugin); both
# hit macOS system-Ruby pollution that we couldn't reliably work around.
# Homebrew ships its own Ruby and is idempotent (`brew uninstall cocoapods`).
#
# Prerequisites (not auto-installed; this script fails with a hint):
#   - Full Xcode (App Store) for simulator builds. CLT-only is insufficient.
#   - Homebrew (https://brew.sh)

def main [] {
    if $nu.os-info.name != "macos" {
        print --stderr "✗ iOS builds require macOS (Xcode is macOS-only)"
        exit 1
    }

    # Xcode
    let xc = (^xcode-select -p | complete)
    if $xc.exit_code != 0 {
        print --stderr "✗ Xcode CLT not installed."
        print --stderr "  Run: xcode-select --install"
        print --stderr "  Or install Xcode from the App Store (covers CLT + simulator)."
        exit 1
    }
    let xc_path = ($xc.stdout | str trim)
    print $"✓ Xcode: ($xc_path)"
    if ($xc_path | str contains "CommandLineTools") {
        print --stderr "⚠  CLT only — iOS simulator builds need full Xcode."
        print --stderr "   Install Xcode from the App Store, then: sudo xcode-select -s /Applications/Xcode.app"
    }

    # Homebrew is required
    if (which brew | is-empty) {
        print --stderr "✗ Homebrew not installed (needed for CocoaPods)."
        print --stderr "  Install: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    }
    print $"✓ Homebrew: ((^brew --version | lines | first | str trim))"

    # CocoaPods via brew — idempotent (brew install is no-op if up to date)
    let pod_works = if (which pod | is-empty) {
        false
    } else {
        (^pod --version | complete).exit_code == 0
    }
    if $pod_works {
        let v = (^pod --version | str trim)
        print $"✓ CocoaPods already installed: ($v)"
    } else {
        print "→ installing cocoapods via brew..."
        ^brew install cocoapods
        if (which pod | is-empty) {
            print --stderr "✗ pod still not on PATH after brew install. See output above."
            exit 1
        }
        let v = (^pod --version | str trim)
        print $"✓ CocoaPods: ($v)"
    }

    # Note: xcodegen, libimobiledevice, libusbmuxd — Tauri's `cargo tauri
    # ios init` auto-installs these via brew on first run. Not our problem.

    # Rust iOS targets
    if (which rustup | is-empty) {
        print "⤬ rustup not on PATH — skipping Rust iOS target install."
        print "  Ensure `rust = \"stable\"` is pinned in your repo's mise.toml, then:"
        print "    rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios"
    } else {
        print "→ adding Rust iOS targets..."
        ^rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
    }

    # iOS Simulator runtime — separate from the SDK. Tauri's build will fail
    # with "Xcode Simulator SDK X.Y is not installed, please open Xcode" if
    # the runtime image (not SDK headers) for the current Xcode's iOS version
    # isn't downloaded.
    let sim_r = (^xcrun simctl list runtimes -j | complete)
    if $sim_r.exit_code == 0 {
        let runtimes = ($sim_r.stdout | from json | get runtimes | where { |r| ($r.identifier | str contains "iOS") })
        if ($runtimes | length) == 0 {
            print "⚠  no iOS simulator runtime installed."
            print "   Run once (large download, ~6 GB):"
            print "     xcodebuild -downloadPlatform iOS"
        } else {
            let names = ($runtimes | get name | str join ", ")
            print $"✓ iOS sim runtime: ($names)"
        }
    }

    print ""
    print "✓ iOS toolchain ready."
    print "  Next:"
    print "    mise run tauri:ios:init   (first time per project)"
    print "    mise run tauri:ios:dev    (connected device or simulator)"
}
