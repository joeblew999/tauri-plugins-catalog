#!/usr/bin/env nu
# tauri:android:setup — install + verify Android tooling for Tauri development.
#
# **No Android Studio required.** Installs cmdline-tools via mise (or the user
# does), then drives `sdkmanager` to install NDK + platforms + build-tools.
#
# Prerequisites (do these first; we fail with a hint if missing):
#   1. Java 17+: handled by this task's mise `tools = { java = "..." }` pin
#   2. sdkmanager on PATH: `mise use -g android-sdk@latest`
#      (uses the vfox:mise-plugins/vfox-android-sdk plugin — cmdline-tools only,
#       no GUI / no Android Studio)
#
# Installs into ANDROID_HOME (default: $HOME/.android-sdk):
#   - NDK 27.0.12077973
#   - platforms;android-36
#   - build-tools;36.0.0
# Plus the 4 Rust Android target triples via rustup.

def main [] {
  # 1. java 17+
  if (which java | is-empty) {
    print --stderr "✗ java not found — this task should pin it via mise. Re-run via `mise run tauri:android:setup`."
    exit 1
  }
  let ver_raw = (^java -version | complete | get stderr | lines | first)
  let java_ver = ($ver_raw | parse --regex '"([0-9]+)' | get capture0?.0? | default "0" | into int)
  if $java_ver < 17 {
    print --stderr $"✗ Java 17+ required, found: ($ver_raw)"
    exit 1
  }
  print $"✓ Java ($java_ver)"

  # 2. sdkmanager (cmdline-tools)
  if (which sdkmanager | is-empty) {
    print --stderr "✗ sdkmanager not on PATH."
    print --stderr "  Install Android cmdline-tools via mise (no Android Studio needed):"
    print --stderr "    mise use -g android-sdk@latest"
    exit 1
  }
  print $"✓ sdkmanager: ((which sdkmanager | get path.0))"

  # 3. ANDROID_HOME — where SDK components (NDK, platforms, build-tools) live
  mut android_home = ($env.ANDROID_HOME? | default "")
  if ($android_home | is-empty) {
    $android_home = $"($env.HOME)/.android-sdk"
    print $"→ ANDROID_HOME not set; defaulting to ($android_home)"
    print $"  To persist, add to your mise.toml [env]: ANDROID_HOME = \"($android_home)\""
    mkdir $android_home
  } else if not ($android_home | path exists) {
    print $"→ ANDROID_HOME set to ($android_home) but does not exist; creating"
    mkdir $android_home
  }
  print $"✓ ANDROID_HOME=($android_home)"

  # 4. accept licenses (sdkmanager prompts; `yes` keeps feeding y until it exits)
  print "→ accepting Android SDK licenses (auto y)..."
  ^yes | ^sdkmanager $"--sdk_root=($android_home)" --licenses out+err> /dev/null

  # 5. install NDK + platform + build-tools (idempotent: sdkmanager skips if present)
  print "→ installing NDK 27.0.12077973 + platform-34 + build-tools 34.0.0..."
  ^sdkmanager $"--sdk_root=($android_home)" --install "ndk;27.0.12077973" "platforms;android-36" "build-tools;36.0.0"

  let ndk_dir = $"($android_home)/ndk/27.0.12077973"
  if not ($ndk_dir | path exists) {
    print --stderr $"✗ expected NDK at ($ndk_dir) but it's not there"
    exit 1
  }
  print $"✓ NDK at ($ndk_dir)"
  print $"  To persist NDK_HOME, add to your mise.toml [env]: NDK_HOME = \"($ndk_dir)\""

  # 6. Rust Android targets
  if (which rustup | is-empty) {
    print "⤬ rustup not on PATH — skipping Rust Android target install."
    print "  Ensure `rust = \"stable\"` is pinned in your repo's mise.toml, then:"
    print "    rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android"
  } else {
    print "→ adding Rust Android targets..."
    ^rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
  }

  print ""
  print "✓ Android toolchain ready (no Android Studio used)."
  print "  Next:"
  print "    mise run tauri:android:init   (first time per project)"
  print "    mise run tauri:android:dev    (with device or — later — emulator)"
}
