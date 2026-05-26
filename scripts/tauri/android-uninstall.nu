#!/usr/bin/env nu
# tauri:android:uninstall — reverse what tauri:android:setup installed.
#
# Default: removes SDK components (NDK 27, platform-34, build-tools 34) via
# sdkmanager + Rust Android targets via rustup. Idempotent.
#
# --purge: also removes the entire ANDROID_HOME directory.
#   (Does NOT remove the mise-managed cmdline-tools — uninstall those with
#   `mise uninstall android-sdk@<ver>` or by editing your mise.toml.)
#
# Usage: nu scripts/tauri/android-uninstall.nu [--dry-run] [--yes] [--purge]

def main [--dry-run, --yes, --purge] {
  let ah = ($env.ANDROID_HOME? | default $"($env.HOME)/.android-sdk")

  if (which sdkmanager | is-empty) {
    print --stderr "⚠  sdkmanager not on PATH — cannot uninstall SDK components."
    if not $purge {
      exit 1
    }
  }

  mut actions = [
    $"sdkmanager --sdk_root=($ah) --uninstall 'ndk;27.0.12077973'",
    $"sdkmanager --sdk_root=($ah) --uninstall 'platforms;android-36'",
    $"sdkmanager --sdk_root=($ah) --uninstall 'build-tools;36.0.0'",
    "rustup target remove aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android",
  ]
  if $purge {
    $actions = ($actions | append $"rm -rf ($ah)")
  }

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

  if not (which sdkmanager | is-empty) {
    ^sdkmanager $"--sdk_root=($ah)" --uninstall "ndk;27.0.12077973"
    ^sdkmanager $"--sdk_root=($ah)" --uninstall "platforms;android-36"
    ^sdkmanager $"--sdk_root=($ah)" --uninstall "build-tools;36.0.0"
  }
  if not (which rustup | is-empty) {
    ^rustup target remove aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
  }
  if $purge and ($ah | path exists) {
    rm -rf $ah
    print $"  removed ($ah)"
  }

  print ""
  print "✓ Uninstall complete."
  if not $purge {
    print $"  ANDROID_HOME ($ah) still exists. To wipe entirely, re-run with --purge."
  }
  print "  cmdline-tools (sdkmanager) are mise-managed: `mise uninstall android-sdk@<ver>`."
  print "  Java is mise-managed: edit your mise.toml or `mise uninstall java@<ver>`."
}
