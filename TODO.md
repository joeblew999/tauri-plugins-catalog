# TODO: Tauri Android setup — nushell scripts

> Goal: replace the multi-page "set up Tauri for Android" ritual with a small set
> of nushell scripts that *install*, *verify*, and *troubleshoot* the toolchain
> idempotently across macOS and Linux.

**Status:** scoping. No scripts written yet. The whole point of this doc is to
work out what we even need before writing code.

Whether this lives in `tauri-plugins-catalog` or splits into its own repo
(`tauri-android-doctor`? `tauri-toolkit`?) is an open question — defer until
the scripts exist and we can see their shape.

---

## Why this needs to exist (the PITA list)

Setting up Tauri for Android currently means stepping through ~10 brittle
prerequisites where any single one being wrong gives a cryptic build failure.
The pain isn't any one tool — it's that they all have to agree on versions,
env vars, and paths, with most of the integration documented across separate
docs (Android, Rust, JDK vendors, Tauri).

Specifically painful pieces we'd want a script to own:

1. **JDK** — Tauri requires JDK 17+. System Java often conflicts. `JAVA_HOME`
   must be visible to *all* child processes (not just login shells).
2. **Android SDK + cmdline-tools** — the bootstrap dance (download, unpack into
   the right nested dir, accept licenses, then use `sdkmanager` to install
   platforms / build-tools / platform-tools).
3. **Android NDK** — separate component, version-pinned by Tauri (currently
   ~27.x?), needs `NDK_HOME` set.
4. **Rust Android targets** — `rustup target add` for `aarch64-linux-android`,
   `armv7-linux-androideabi`, `i686-linux-android`, `x86_64-linux-android`.
5. **`.cargo/config.toml` linker stanzas** — per-target linker pointing at NDK
   toolchain binaries. Path varies by NDK version and host arch.
6. **Tauri CLI** — `cargo install tauri-cli` vs `@tauri-apps/cli`; project
   conventions vary.
7. **Env-var leakage** — Gradle, sdkmanager, Tauri, Cargo all need to see the
   same `JAVA_HOME` / `ANDROID_HOME` / `NDK_HOME`. mise activation handles
   shell, but Tauri spawning gradle is the most common breakage point.
8. **Signing keys** — keystore generation, password storage, integration with
   `tauri.conf.json` for release builds.
9. **Emulator / device** — `adb` install, AVD creation, KVM access on Linux,
   "no device" debugging.
10. **Cross-arch host quirks** — Apple Silicon → arm64 Android; Linux x86_64 →
    arm64. NDK toolchain dir names depend on host arch.

---

## Research phase (do this first)

Before writing any script, answer these. **Each item is a discrete research
task; the script design depends on the answers.**

- [ ] Read [Tauri Android prerequisites](https://v2.tauri.app/start/prerequisites/#android)
      end-to-end on the current `v2` docs. Capture the exact required versions
      in a `VERSIONS.md` (JDK, NDK, SDK platforms, build-tools).
- [ ] Run `tauri android init` on a clean machine and *diff* what it does vs
      what the docs say you have to do manually. The gap is what our scripts
      should own.
- [ ] Identify which env vars Tauri itself reads at build time (grep
      `tauri-cli` source). Confirm whether mise's `[env]` blocks propagate to
      gradle subprocesses without manual exporting.
- [ ] Check if mise has registry entries for the Android SDK / NDK / JDK
      (it does for `java`, possibly `android-sdk`, `android-ndk` via aqua?).
      If yes, half the work is one `mise.toml` away.
- [ ] Find the canonical NDK version Tauri 2.x expects. Tauri pins it
      somewhere in the build; don't guess.
- [ ] Survey the community pain — search "tauri android" in GH issues across
      `tauri-apps/tauri` and `tauri-apps/plugins-workspace` for the top 20
      issues tagged android / build. Categorise by failure mode.
- [ ] Confirm macOS vs Linux differences. (Windows is out of scope for v1; see
      below.)
- [ ] Decide: do we wrap `tauri android init/dev/build` or replace it?
      Wrapping is safer; replacing is only justified if `init` is the problem.

---

## Sketched script set (subject to research)

Not finalised — these are the shape of what the research above should validate
or kill.

All scripts live under `scripts/tauri/` and are exposed as mise tasks under the
`tauri:` namespace (e.g. `mise run tauri:doctor`).

| script | mise task | purpose | runs as |
| ------ | --------- | ------- | ------- |
| `doctor.nu` | `tauri:doctor` | Verify every prerequisite. Print red/green per item. Exit nonzero if anything is wrong, with the *exact* remediation command. | one-shot |
| `bootstrap-macos.nu` | `tauri:bootstrap:macos` | Install JDK + SDK cmdline-tools + NDK via mise (where possible) or direct download. Idempotent. | one-shot per machine |
| `bootstrap-linux.nu` | `tauri:bootstrap:linux` | Same as above, Linux flavour. KVM check included. | one-shot per machine |
| `init-project.nu` | `tauri:init` | Inside a Tauri project: generate `.cargo/config.toml` linker stanzas, ensure `tauri android init` has been run, generate dev keystore. | per project |
| `build.nu` | `tauri:build` | Wrap `cargo tauri android build` with sanity checks that catch known failure modes early (wrong JDK, missing target, etc.). | per build |

`doctor.nu` is the most important — it's the entry point a frustrated dev runs
when something is broken.

---

## Out of scope (v1)

- **Windows.** WSL2 is fine but native Windows Android dev is a different
  beast; revisit later.
- **iOS setup.** Different toolchain, different pain. Separate effort.
- **Rebuilding `tauri android init`.** Wrap, don't replace. Tauri's own
  scaffolder is the source of truth for the gen/android tree.
- **CI Android builds.** Local-machine setup only for now. CI is a separate
  problem (it needs the same toolchain but installed deterministically).

---

## Open questions (need the user to weigh in or research to answer)

- [ ] **Repo location**: live here, or split out? Decide once `doctor.nu` works.
- [ ] **mise vs direct install**: prefer mise for everything, or accept that
      Android SDK/NDK are too big/awkward for mise and use direct download?
- [ ] **Version pinning policy**: pin to whatever Tauri current docs require,
      or stay one minor behind for stability?
- [ ] **Where does keystore secret live?** fnox/keychain pattern (per user's
      standard stack) or a project-local encrypted file?
- [ ] **Do we ship a `dev.keystore` fixture** for first-build smoke tests, or
      force the user to generate one?

---

## References to dig through

- https://v2.tauri.app/start/prerequisites/#android — canonical setup
- https://v2.tauri.app/develop/configuration-files/ — `tauri.conf.json` schema
- https://github.com/tauri-apps/tauri — search issues filtered by `android`
- https://developer.android.com/tools/sdkmanager — sdkmanager CLI ref
- https://github.com/jdx/mise — relevant plugins for java/android tooling
- Tauri Discord #mobile channel — anecdotal pain points (not searchable from
  here; capture during research)

---

## Working log

Append to this section as research happens. Date-stamp entries. Don't delete
old entries — they're useful when the same dead-end gets revisited.

### 2026-05-26
- TODO.md scaffold created. No research done yet.
