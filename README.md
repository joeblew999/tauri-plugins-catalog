# tauri-plugins-catalog

[![ci](https://github.com/joeblew999/tauri-plugins-catalog/actions/workflows/ci.yml/badge.svg)](https://github.com/joeblew999/tauri-plugins-catalog/actions/workflows/ci.yml)
[![ci-full](https://github.com/joeblew999/tauri-plugins-catalog/actions/workflows/ci-full.yml/badge.svg)](https://github.com/joeblew999/tauri-plugins-catalog/actions/workflows/ci-full.yml)
[![freshness](https://github.com/joeblew999/tauri-plugins-catalog/actions/workflows/freshness.yml/badge.svg)](https://github.com/joeblew999/tauri-plugins-catalog/actions/workflows/freshness.yml)

## Git clone & go

Works on **Mac, Linux, Windows** — CI proves all three on every push to main
([ci-full workflow](.github/workflows/ci-full.yml) installs the full Android
toolchain on each OS and builds a real APK).

```sh
# 1. Clone
git clone https://github.com/joeblew999/tauri-plugins-catalog.git
cd tauri-plugins-catalog

# 2. Install base toolchain (mise reads mise.toml)
mise install

# 3. Tauri CLI (prebuilt binary, fast)
cargo binstall --no-confirm tauri-cli

# 4. Verify base layer (should be all green)
mise run tauri:doctor:base
```

For **Android** development:

> ⚠️ **Windows is currently blocked** by an upstream bug in
> `mise-plugins/vfox-android-sdk` ([issue #8](https://github.com/mise-plugins/vfox-android-sdk/issues/8)
> — the plugin's post-install verifies `sdkmanager` without the `.bat`
> extension Windows ships). Use WSL2 or wait for the fix.
> macOS + Linux work end-to-end (ci-full verifies real APK build on both).

```sh
# Linux only: webview deps
sudo apt-get install libwebkit2gtk-4.1-dev libsoup-3.0-dev librsvg2-dev pkg-config

# Install cmdline-tools + NDK + platforms + build-tools + Rust Android targets
mise use -g vfox:mise-plugins/vfox-android-sdk@20.0
mise run tauri:android:setup

# Persist NDK_HOME (one-time)
mise set --global NDK_HOME="$(mise where vfox:mise-plugins/vfox-android-sdk)/ndk/27.0.12077973"

# Build the reference example end-to-end
mise run examples:build tauri-android-test
```

For **iOS** (macOS host only):

```sh
mise run tauri:ios:setup
xcodebuild -downloadPlatform iOS   # one-time ~10 GB Apple download
mise run tauri:doctor:ios          # should be fully green
```

To uninstall the Android/iOS toolchain cleanly:

```sh
mise run tauri:android:uninstall   # [--dry-run] [--yes] [--purge]
mise run tauri:ios:uninstall       # [--dry-run] [--yes]
```

Structured catalog of Tauri v2 plugins as JSONL.

- [plugins.jsonl](plugins.jsonl) — one plugin per line, schema in [schema.nuon](schema.nuon)
- [examples.jsonl](examples.jsonl) — real Tauri apps for toolchain testing, schema in [example.schema.nuon](example.schema.nuon)
- [TODO.md](TODO.md) — Tauri toolchain script roadmap + research log

## Quick use

```nu
# load the catalog as a structured table
let plugins = (open plugins.jsonl --raw | lines | each { from json })

# count entries
$plugins | length

# list mobile-supporting plugins
$plugins | where { |p| $p.platforms.ios == "yes" or $p.platforms.android == "yes" } | get name

# all official plugin crate names
$plugins | where official | get crate

# plugins that have an active fork to prefer for installs
$plugins | where active_fork != null | select name repo active_fork
```

## Tasks

Catalog management (`scripts/plugins/`):

```sh
mise run plugins:validate          # plugins.jsonl matches schema.nuon
mise run plugins:count             # entry count + official/third-party split
mise run plugins:sort              # sort plugins.jsonl by name (in place)
mise run plugins:render            # regenerate the plugin table below
mise run plugins:search <term>     # substring match on name/description/tags
mise run plugins:install <name>    # print Cargo.toml + package.json snippets (respects active_fork)
mise run plugins:freshness         # check upstream pushed_at, detect drift (needs gh CLI)
mise run examples:validate         # verify examples.jsonl against example.schema.nuon
```

Tauri toolchain scripts (`scripts/tauri/`):

```sh
# Doctor — composable: orchestrator + per-platform sub-doctors
mise run tauri:doctor              # runs base + android + ios sub-doctors
mise run tauri:doctor:base         # base only (rust, node, tauri-cli, webview deps)
mise run tauri:doctor:android      # Android only (Java, ANDROID_HOME, NDK, Rust targets)
mise run tauri:doctor:ios          # iOS only (Xcode, CocoaPods, Rust iOS targets; macOS-gated)

# Android — install + verify, then per-project lifecycle
mise run tauri:android:setup       # install NDK 27, add Rust Android targets
mise run tauri:android:init        # one-time per project: generate gen/android
mise run tauri:android:dev         # hot-reload on connected device or emulator
mise run tauri:android:build       # release APK/AAB
mise run tauri:android:uninstall   # reverse setup: remove NDK + Rust targets ([--dry-run] [--yes])

# iOS — macOS host only
mise run tauri:ios:setup           # install Xcode CLT + CocoaPods + Rust iOS targets
mise run tauri:ios:init            # one-time per project: generate gen/apple
mise run tauri:ios:dev             # hot-reload on connected device or simulator
mise run tauri:ios:build           # release IPA
mise run tauri:ios:uninstall       # reverse setup: remove CocoaPods + Rust targets ([--dry-run] [--yes])
```

See [TODO.md](TODO.md) for the broader plan and research log.

## Plugins

<!-- BEGIN:plugins -->
### Cross-platform (11)

| Plugin | Source | Description | Win | Mac | Lin | iOS | Android |
| ------ | ------ | ----------- | :-: | :-: | :-: | :-: | :-----: |
| [clipboard-manager](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/clipboard-manager) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Read and write to the system clipboard. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [deep-link](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/deep-link) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Set your Tauri application as the default handler for an URL. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [dialog](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/dialog) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Native system dialogs for opening and saving files along with message dialogs. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [http](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/http) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Access the HTTP client written in Rust. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [log](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/log) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Configurable logging. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [notification](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/notification) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Send message notifications (brief auto-expiring OS window element) to your user. Can also be used with the Notification Web API. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [opener](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/opener) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Open files and URLs using their default application. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [os](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/os) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Read information about the operating system. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [sql](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/sql) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Interface with SQL databases. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [store](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/store) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Persistent key value storage. | ✅ | ✅ | ✅ | ✅ | ✅ |
| [upload](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/upload) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Tauri plugin for file uploads through HTTP. | ✅ | ✅ | ✅ | ✅ | ✅ |

### Desktop (14)

| Plugin | Source | Description | Win | Mac | Lin | iOS | Android |
| ------ | ------ | ----------- | :-: | :-: | :-: | :-: | :-----: |
| [autostart](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/autostart) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Automatically launch your app at system startup. | ✅ | ✅ | ✅ | ❌ | ❌ |
| [cli](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/cli) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Parse arguments from your Command Line Interface. | ✅ | ✅ | ✅ | ❌ | ❌ |
| [fs](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/fs) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Access the file system. | ✅ | ✅ | ✅ | ? | ? |
| [global-shortcut](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/global-shortcut) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Register global shortcuts. | ✅ | ✅ | ✅ | ? | ? |
| [localhost](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/localhost) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Use a localhost server in production apps. | ✅ | ✅ | ✅ | ? | ? |
| [persisted-scope](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/persisted-scope) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Persist runtime scope changes on the filesystem. | ✅ | ✅ | ✅ | ? | ? |
| [positioner](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/positioner) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Move windows to common locations. | ✅ | ✅ | ✅ | ❌ | ❌ |
| [process](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/process) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | APIs to access the current process. To spawn child processes, see the shell plugin. | ✅ | ✅ | ✅ | ? | ? |
| [shell](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/shell) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Access the system shell. Allows you to spawn child processes and manage files and URLs using their default application. | ✅ | ✅ | ✅ | ? | ? |
| [single-instance](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/single-instance) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Ensure a single instance of your tauri app is running. | ✅ | ✅ | ✅ | ❌ | ❌ |
| [stronghold](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/stronghold) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Encrypted, secure database. | ✅ | ✅ | ✅ | ? | ? |
| [updater](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/updater) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | In-app updates for Tauri applications. | ✅ | ✅ | ✅ | ❌ | ❌ |
| [websocket](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/websocket) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Open a WebSocket connection using a Rust client in JS. | ✅ | ✅ | ✅ | ? | ? |
| [window-state](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/window-state) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Persist window sizes and positions. | ✅ | ✅ | ✅ | ❌ | ❌ |

### Mobile (11)

| Plugin | Source | Description | Win | Mac | Lin | iOS | Android |
| ------ | ------ | ----------- | :-: | :-: | :-: | :-: | :-----: |
| [auth](https://github.com/inKibra/tauri-plugins/tree/HEAD/packages/tauri-plugin-auth) | [inKibra](https://github.com/inKibra/tauri-plugins) → [macro-inc](https://github.com/macro-inc/tauri-plugins) | Authentication APIs with iOS keychain integration via ASWebAuthenticationSession. | ❌ | ❌ | ❌ | ✅ | ❌ |
| [barcode-scanner](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/barcode-scanner) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Allows your mobile application to use the camera to scan QR codes, EAN-13 and other kinds of barcodes. | ? | ? | ? | ✅ | ✅ |
| [biometric](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/biometric) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Prompt the user for biometric authentication on Android and iOS. | ? | ? | ? | ✅ | ✅ |
| [context-menu](https://github.com/inKibra/tauri-plugins/tree/HEAD/packages/tauri-plugin-context-menu) | [inKibra](https://github.com/inKibra/tauri-plugins) → [macro-inc](https://github.com/macro-inc/tauri-plugins) | Native iOS context menus. | ❌ | ❌ | ❌ | ✅ | ❌ |
| [geolocation](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/geolocation) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Get and track current device position. | ? | ? | ? | ✅ | ✅ |
| [haptics](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/haptics) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Haptic feedback and vibrations. | ? | ? | ? | ✅ | ✅ |
| [iap](https://github.com/inKibra/tauri-plugins/tree/HEAD/packages/tauri-plugin-iap) | [inKibra](https://github.com/inKibra/tauri-plugins) → [macro-inc](https://github.com/macro-inc/tauri-plugins) | Handle in-app purchases on iOS. | ❌ | ❌ | ❌ | ✅ | ❌ |
| [map-display](https://github.com/inKibra/tauri-plugins/tree/HEAD/packages/tauri-plugin-map-display) | [inKibra](https://github.com/inKibra/tauri-plugins) → [macro-inc](https://github.com/macro-inc/tauri-plugins) | Display and interact with native maps on iOS. | ❌ | ❌ | ❌ | ✅ | ❌ |
| [nfc](https://github.com/tauri-apps/plugins-workspace/tree/HEAD/plugins/nfc) | [tauri-apps](https://github.com/tauri-apps/plugins-workspace) | Read and write NFC tags on Android and iOS. | ? | ? | ? | ✅ | ✅ |
| [ota](https://github.com/inKibra/tauri-plugins/tree/HEAD/packages/tauri-plugin-ota) | [inKibra](https://github.com/inKibra/tauri-plugins) | Over-the-air updates: ship JavaScript and frontend asset updates after App Store approval without submitting a new binary. | ❌ | ❌ | ❌ | ✅ | ❌ |
| [sharing](https://github.com/inKibra/tauri-plugins/tree/HEAD/packages/tauri-plugin-sharing) | [inKibra](https://github.com/inKibra/tauri-plugins) → [macro-inc](https://github.com/macro-inc/tauri-plugins) | Share content from your Tauri application on iOS via the native share sheet. | ❌ | ❌ | ❌ | ✅ | ❌ |
<!-- END:plugins -->

## Sources

- Official: [tauri-apps/plugins-workspace](https://github.com/tauri-apps/plugins-workspace)
- Third-party: added on demand
