# Code Review: trance (crateria/trance)

**Scope:** `/home/jeryd/Projects/ubermetroid/trance`  
**Focus:** Security (plugin load, D-Bus trust, path handling, systemd hardening), correctness/architecture, error handling, packaging, testing, quality strengths  
**Date:** 2026-07-10  
**Constraint:** Read-only review; no code changes.

---

## Overall assessment

Trance is a thoughtfully layered Wayland screensaver stack: a hardened user-session daemon, a shared D-Bus client crate, CLI/TUI/applet front-ends, and an allowlisted `libloading` plugin host. The security design for plugin resolution is clearly intentional and above average for desktop tooling—basename allowlists, system-path preference over `~/.local`, world-writable rejection, and root-ownership checks under `/usr` show real threat modeling. D-Bus control-path auth and systemd unit hardening (`ProtectSystem=strict`, `MemoryDenyWriteExecute`, `NoNewPrivileges`, etc.) are documented and partially battle-tested. Residual risk concentrates where convenience meets hardening: production control auth often falls back to same-UID when peer `/proc/<pid>/exe` is unreadable; `org.freedesktop.ScreenSaver` methods (especially `SetActive`) are unauthenticated on the session bus; D-Bus/CLI preview uses `LaunchMode::Preview`, which prefers developer build trees over packaged plugins; plugins still `dlopen` into the daemon with no ABI versioning or process sandbox; and presentation state does not restart when switching preview savers while an overlay is already active. Packaging maintainer scripts are carefully best-effort and upgrade-aware—strong operational hygiene—while automated testing is solid at unit level but thin for end-to-end D-Bus/auth/presentation behavior.

---

## Findings

### Critical

_None identified that enable cross-user privilege escalation under the documented session-bus / same-user threat model._

Plugin load is intentionally in-process for an already-session-privileged daemon; that is full process compromise if a trusted `.so` is malicious, but it is not a local multi-user privilege boundary by itself.

---

### High

#### H1. `org.freedesktop.ScreenSaver::SetActive` can force presentation with no control-peer auth

**Where:** `trance-daemon/src/dbus_server/screensaver.rs` (`set_active`, also `simulate_user_activity`, `lock`)

Any client on the session bus can call `SetActive(true)`, which enqueues `DaemonCommand::Preview(saver)` using the configured active saver (default `beams`). That bypasses `require_control_peer` used on the proprietary `io.github.ubermetroid.trance` interface. Session bus is same-user scoped, but every app in the session (browsers, Electron apps, scripts) can:

- Force fullscreen layer-shell overlays (UI denial / cover attack)
- Dismiss overlays via `SetActive(false)` / `SimulateUserActivity` / `Lock` (weakens “screensaver is up” expectations)

`Inhibit`/`UnInhibit` being open is protocol-normal; **starting** presentation is not.

**Fix guidance:**

- Treat `SetActive(true)` as privileged (control-peer auth or drop it / map to a no-op and document).
- Keep unauthenticated `Inhibit` / `GetActive` as needed for freedesktop compatibility.
- If activation must stay for DE integration, require a short-lived inhibit cookie exchange or polkit (policy file already ships but is unused—see M5).

#### H2. Preview / `run-plugin` resolve with `LaunchMode::Preview`, preferring `~/Projects/...` over system packages

**Where:**

- `trance-runner/src/launcher.rs` (`resolve_saver_binary` search order for `Preview`)
- `trance-daemon/src/dbus_server/service.rs` (`preview` resolves with `LaunchMode::Preview`)
- `trance-daemon/src/daemon/presentation.rs` (`reason == "preview"` → `LaunchMode::Preview`)
- `trance-daemon/src/main.rs` (`run-plugin` uses `LaunchMode::Preview`)

For Preview mode, search order is **dev dirs first**, then trusted install trees. Dev paths include hardcoded:

- `$HOME/Projects/crateria/trance-plugins/...`
- `$HOME/Projects/ubermetroid/trance-plugins/...`
- `$HOME/Projects/trance-plugin-<name>/...`

A leftover or attacker-written `libscreensaver_storm.so` under a personal build tree can shadow (or substitute for) the packaged plugin when previewing—even on a production install—while still passing `is_trusted_plugin_path` because those dirs are in the trusted set for Preview.

**Fix guidance:**

- Production D-Bus preview and packaged `run-plugin` should use `LaunchMode::Daemon` only.
- Keep `Preview`/dev search for explicit developer env (e.g. `TRANCE_DEV_PLUGINS=1` or debug builds only).
- Never put developer trees ahead of `/usr/libexec/trance/screensavers` in release builds.

#### H3. Same-UID D-Bus control fallback collapses peer-binary trust when `/proc/<peer>/exe` is unreadable

**Where:** `trance-daemon/src/dbus_server/auth.rs` (`is_trusted_control_peer`, `PeerExeCheck::Unreadable`)  
**Docs:** `SECURITY.md`

When peer exe cannot be canonicalized (documented as common under hardening), any connection with matching Unix UID is accepted. Under that condition, the carefully enforced trusted basenames (`trance`, `trance-applet`, `trance-tui`, `trance-cli`) and path/root-ownership checks never run. Any same-user process can then enable/disable, set saver, change timeout, and preview.

This is an explicit, documented tradeoff (control must work when systemd blocks peer-exe reads), but it is still the primary residual control-plane risk on hardened installs.

**Fix guidance:**

- Prefer peer credentials that do not require ptrace-like `/proc/exe` access: e.g. Linux security labels, sealed memfd tokens, or a private Unix socket with `SO_PEERCRED` + a start-time shared secret written only to `XDG_RUNTIME_DIR` with mode `0600`.
- Or use polkit `auth_self` for mutate methods (policy already installed).
- At minimum, rate-limit / audit log all same-UID fallback accepts at `warn` with peer bus name, and consider denying `Preview` on fallback while allowing read-only `GetStatus`.

#### H4. Preview while a presentation is already active does not switch savers

**Where:** `trance-daemon/src/daemon/idle_logic.rs` (`drive_presentation_chain`)  
**Related:** `trance-daemon/src/daemon/tick_loop.rs` (`DaemonCommand::Preview` only sets `preview_name`)

```text
} else if let Some(name) = preview_name.clone() {
    if !presentation.is_active() {
        start_presentation(...);
    }
}
```

If idle presentation (or a previous preview) is active, a new `Preview("storm")` updates `preview_name` but **never** restarts the plugin when `current_saver` differs. Users experience “preview does nothing” during idle overlay or when clicking through savers in the applet/TUI without stopping first.

**Fix guidance:**

- On `Preview(name)`, if `presentation.is_active() && current_saver != name`, stop then start.
- Or compare `preview_name` vs `current_saver` each tick and restart when they diverge under preview mode.

---

### Medium

#### M1. Plugins load in-process with no ABI versioning

**Where:** `trance-runner/src/plugin_session/loading.rs`, `trance-api/src/screensaver.rs`

`create_screensaver` / `destroy_screensaver` are raw C symbols returning `*mut ScreensaverInstance` with a Rust trait object inside. There is no:

- Plugin ABI/API version symbol
- Stable C vtable (only Rust trait objects across `.so` boundary)
- Separate helper process / seccomp profile for presentation

A plugin built against a different `trance-api` layout can crash the daemon (or worse, corrupt memory). Crash is somewhat contained by systemd restart, but overlay/session disruption remains.

**Fix guidance:**

- Export `trance_plugin_abi_version()` and refuse load on mismatch.
- Longer term: out-of-process plugin renderer with SHM frame handoff (matches layer-shell buffer model already).

#### M2. World-writable check only; group-writable / sticky multi-user trees not covered

**Where:** `trance-runner/src/launcher.rs` (`is_trusted_plugin_path_cached`)

Only `mode & 0o002` (other-write) is rejected. Group-writable plugins (`g+w`) under a shared group directory that is still a “trusted” search root (including user-influenced `XDG_DATA_DIRS` entries) can still load. Root ownership is enforced only for paths under `/usr`.

**Fix guidance:**

- Also reject `g+w` unless owner is root and group is a known admin group—or require mode `0644`/`0755` and uid 0 for any path under system prefixes.
- For non-`/usr` roots, require ownership == daemon euid and not group/other writable.

#### M3. External inhibit watcher via `dbus-monitor` text parsing is fragile and uncapped

**Where:** `trance-daemon/src/dbus_server/watchers.rs` (`watch_external_dbus_inhibits`)  
**Related:** `trance-daemon/src/inhibit.rs` (`add_with_cookie` has no per-client capacity)

Native `Inhibit` path caps 32 inhibitors per client; `add_with_cookie` used by the external monitor does not. Parsing `dbus-monitor` line format is brittle across versions/locales and depends on spawning an external process forever (extra attack/DoS surface under session compromise).

**Fix guidance:**

- Prefer a second zbus match rule / proxy on known names, or drop external monitoring if trance owns `org.freedesktop.ScreenSaver`.
- Apply the same per-client and global caps to `add_with_cookie`.
- Bound `pending_inhibits` map size.

#### M4. Pidfile acquire is racy; stop fallback can SIGTERM arbitrary same-user PIDs

**Where:**

- `trance-daemon/src/daemon/mod.rs` (`acquire_pidfile`)
- `trance-applet/src/daemon_client.rs` (`stop_daemon_service` kill fallback)

Classic check-then-write pidfile without `O_EXCL`/flock. Two concurrent starts can both pass the `kill(pid,0)` check. Applet stop reads the pid file and `SIGTERM`s without verifying `/proc/pid/exe` is `trance-daemon`.

**Fix guidance:**

- Use `fs2`/`nix` flock or create with `O_CREAT|O_EXCL` and write pid under the lock.
- Before kill, resolve `/proc/<pid>/exe` basename/path the same way auth does.

#### M5. Polkit policy is packaged but never consulted

**Where:** `trance-daemon/assets/io.github.ubermetroid.trance.policy`, installed via deb/rpm metadata; no `pkcheck` / polkit agent usage in daemon

Shipped action `io.github.ubermetroid.trance.configure` with `allow_active=yes` is security theater today—code never calls it. Operators may believe configure is polkit-gated.

**Fix guidance:**

- Wire mutate methods through polkit, **or** stop shipping the policy until used, and document session-bus trust model clearly in man pages.

#### M6. `org.freedesktop.ScreenSaver` name claim failure is ignored

**Where:** `trance-daemon/src/dbus_server/mod.rs`

```rust
let _ = connection.request_name("org.freedesktop.ScreenSaver").await;
```

If another screensaver already owns the well-known name, trance still serves the interface on its own connection but DE clients talking to the well-known name never reach it. Silent failure complicates “doctor” and multi-screensaver installs.

**Fix guidance:** Log at `error`/`warn` with context; surface in `trance doctor` and status; optionally integrate with portal/idle inhibit only.

#### M7. Failed plugin start leaves `preview_name` set → error spam loop

**Where:** `trance-daemon/src/daemon/presentation.rs` + `idle_logic.rs`

On load failure, presentation stays inactive, `preview_name` remains `Some`, and every tick (~250 ms) retries `start_presentation`, logging errors.

**Fix guidance:** Clear `preview_name` after N failures or set a backoff; surface last error in D-Bus status.

#### M8. Hardcoded developer paths and dual brand trees in resolver

**Where:** `trance-runner/src/launcher.rs` (`dev_plugin_dirs`)

Hardcoded `$HOME/Projects/{crateria,ubermetroid}/trance-plugins` couples security-sensitive path trust to personal monorepo layout and rebrand history.

**Fix guidance:** Drive solely from env / Cargo workspace detection in debug builds; never compile default home-layout paths into release.

#### M9. systemd hardening gaps vs. threat model comments

**Where:** `trance-daemon/assets/trance-daemon.service`

Strengths: `NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`, `ProtectHome=read-only`, `MemoryDenyWriteExecute`, `RestrictNamespaces`, etc.

Gaps:

- `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6` — comments admit AF_INET unused today; unnecessary network AF expands post-RCE surface.
- No `SystemCallFilter`, `ProtectKernelTunables`, `ProtectControlGroups`, `PrivateDevices`, `UMask=0077`.
- In-process plugins can still use allowed families and broad syscalls.

**Fix guidance:** Drop `AF_INET`/`AF_INET6` until needed; add a conservative `@system-service` filter and document plugin implications for MDWE/dlopen (generally OK for file-backed RX maps).

#### M10. D-Bus object path still uses `crateria` while service is `ubermetroid`

**Where:** `crates/trance-dbus/src/lib.rs` (`OBJECT_PATH = "/io/github/crateria/trance"`, `SERVICE_NAME = "io.github.ubermetroid.trance"`)

Rebrand inconsistency risks client skew and documentation mistakes; not a direct vuln, but a long-term compatibility footgun.

**Fix guidance:** Alias both paths during a deprecation window; update all clients atomically.

---

### Low

#### L1. `SetTimeout` is applied twice (D-Bus + tick loop)

**Where:** `trance-daemon/src/dbus_server/service.rs` (`apply_command` then `command_tx.send`); `tick_loop.rs` applies again

Double write of config on every timeout change. Harmless but noisy and can race with concurrent `reload_config_if_due`.

**Fix:** Send-only on D-Bus for live effects, or apply-only and separately poke idle monitor.

#### L2. Config parser is a hand-rolled line splitter, not real YAML

**Where:** `trance-daemon/src/config.rs`

Works for the controlled key set; rejects unknown keys by ignore. Nested YAML, multi-line, or odd quoting will silently mis-parse. No atomic write (`write` temp + rename).

**Fix:** `serde_yaml` + atomic replace; keep allowlist validation.

#### L3. Debian `prerm` does not filter system UIDs like shared lib

**Where:** `trance-daemon/debian/prerm` vs `assets/packaging/user-service-lib.sh` (`is_desktop_uid`)

Shared lib skips UID &lt; 1000; deb `prerm` does not. Usually harmless (no bus for system users) but inconsistent with RPM/post scripts.

#### L4. `TRANCE_DBUS_TRUST_ALL` correctly debug-only — good, but tests don’t cover release gating

**Where:** `auth.rs`

Logic is right (`cfg!(debug_assertions)`). No compile-time test/assert that release builds ignore the env var (would need dual-build CI).

#### L5. Global inhibitor list has no absolute cap

**Where:** `inhibit.rs`

Per-client 32 is good; many clients can still grow a large vector and keep idle suppressed forever (session DoS by volume).

#### L6. Clippy still allows `unwrap_used` / `expect_used` workspace-wide

**Where:** root `Cargo.toml` lints

Many production paths use `.unwrap()` on mutexes (poison = panic). Acceptable for internal locks, but release `panic = "abort"` means poisoned mutex takes down the daemon hard.

#### L7. Applet/TUI direct-spawn fallback bypasses systemd hardening

**Where:** `trance-applet/src/daemon_client.rs`, `trance-tui/src/main.rs`

If `systemctl --user enable --now` fails, they `spawn` `trance-daemon` without the unit’s sandbox. Useful recovery, weaker security posture until user restarts via systemd.

**Fix:** Prefer failing with `trance doctor --fix` guidance over unconfined spawn; or re-exec via `systemd-run --user`.

#### L8. Allowlist / plugin set must be manually kept in sync with trance-plugins

**Where:** `ALLOWED_SAVERS` in `launcher.rs` (10 names)

Adding a plugin requires core release. Acceptable for security; document release checklist.

---

### Nit

#### N1. Duplicate plugin host paths

`run_plugin_fullscreen` in `trance_runner.rs` duplicates `PluginSession` loading patterns.

#### N2. Status map conversion falls back to `0u32` on type errors

`DaemonStatus::to_map` in `status.rs` can mask bugs by inserting wrong types.

#### N3. `f64` → `f32` cast on `set_render_scale` without explicit documentation

#### N4. LICENSE headers mix MIT and Apache-2.0 across files

Daemon main claims Apache-2.0; many modules say MIT. Align with package license metadata.

#### N5. `detect_screensavers` always lists full allowlist even if not installed

CLI/UI may show savers that fail resolve until filtered by `installed_savers()`—daemon list path filters; ensure all UIs use the filtered API.

#### N6. Line-limit tooling is runner-only

`check_limits` covers `trance-runner`; daemon/cli growth is unconstrained by the same policy.

---

## Notable quality strengths

1. **Clear crate split:** `trance-daemon` / `trance-cli` / `trance-applet` / `trance-tui` / `trance-runner` / `trance-api` / `trance-dbus` / Wayland crates — ownership boundaries are readable.
2. **Plugin path hardening is real:** allowlist, sanitize, no path separators, system-before-user search, canonicalize containment, o+w refuse, root-owned `/usr` plugins (`launcher.rs`, `discovery.rs`).
3. **Control-path auth exists and is tested** for peer names, same-UID fallback edges, and world-writable peer binaries (`auth.rs` unit tests).
4. **Inhibit cookie ownership** is correct (`remove_for_client`); client disconnect cleanup via `NameOwnerChanged`.
5. **systemd user packaging is upgrade-aware:** leave running on upgrade, restart in post/posttrans, best-effort never fails transactions, remove legacy XDG autostart, desktop-UID filtering in shared shell lib.
6. **Operational UX:** `trance doctor --fix`, journald tracing when `JOURNAL_STREAM` set, structured command validation (timeout 1–240, render_scale clamp).
7. **Workspace engineering hygiene:** `just verify`, clippy pedantic baseline, `deny.toml`, `cargo audit` target, release size opts (`opt-level=z`, LTO, strip), panic=abort.
8. **Presentation architecture:** dedicated plugin thread, stop flag + join, layout/span multi-monitor handling with tests (`layout_tests.rs`), FPS/render-scale options.
9. **SECURITY.md** documents the actual hardening notes rather than marketing fluff.
10. **Deprecations handled carefully:** GPU field/methods retained as no-ops with comments to avoid client breakage.

---

## Testing gaps

| Area | Current | Gap |
|------|---------|-----|
| Plugin resolve | Strong unit tests (`launcher_tests.rs`) | No tempdir integration with real files, modes, uid mocks |
| D-Bus auth | Unit tests for peer list + same-UID | No session-bus integration / hardened-unit simulation |
| ScreenSaver iface | Command enqueue unit tests | No auth regression test for `SetActive` |
| Presentation FSM | None for idle_logic | Preview-switch, inhibit, lock, failed-load loops untested |
| Config load/save | Default-value only | No round-trip / malicious line / atomicity tests |
| Packaging scripts | Manual | No shellcheck-in-CI / dry-run of for_each_user_session |
| Inhibit | Good unit coverage | `add_with_cookie` uncapped path untested |
| End-to-end | None in-repo | No smoke: start daemon → D-Bus preview → stop under xvfb/wayland mock |
| ABI | None | Plugin built against prior API not tested |

---

## Top 5 recommended next engineering investments

1. **Close the ScreenSaver activation hole and tighten preview resolution (H1 + H2)**  
   Auth or neutralize `SetActive(true)`; force `LaunchMode::Daemon` for production preview/`run-plugin`; gate dev trees behind explicit debug env. Highest security ROI for little code.

2. **Fix presentation FSM for preview switching and failed starts (H4 + M7)**  
   Restart on saver change; backoff/clear on load failure. Directly improves applet/TUI “click through savers” reliability—the product’s hero path.

3. **Replace same-UID exe-unreadable fallback with a stronger local capability (H3)**  
   Runtime-dir token, polkit, or private control socket so hardened units do not equate “any same-user D-Bus peer” with “trance CLI.” Keep current fallback only as temporary compatibility with loud logging.

4. **Plugin load contract: ABI version + ownership/mode policy expansion (M1 + M2)**  
   Version gate every `.so`; reject group-writable and non-euid-owned non-system plugins; add tempdir-based integration tests for resolve edge cases.

5. **Add a thin integration/smoke suite + doctor coverage for D-Bus/name claim (M3, M6, testing gaps)**  
   One CI job: build beams plugin fixture, resolve path, load symbols, exercise inhibit caps, assert ScreenSaver name ownership status. Retire or strictly cap `dbus-monitor` text scraping once ownership is reliable.

---

## Architecture snapshot (for reviewers)

```text
┌─────────────┐  ┌──────────────┐  ┌────────────┐
│ trance-cli  │  │ trance-applet│  │ trance-tui  │
└──────┬──────┘  └──────┬───────┘  └──────┬─────┘
       │  trance-dbus   │                 │
       └────────────────┼─────────────────┘
                        ▼
              ┌──────────────────┐
              │  trance-daemon   │  user systemd unit (hardened)
              │  D-Bus + idle    │
              └────────┬─────────┘
                       │ LaunchMode + PluginSession
                       ▼
              ┌──────────────────┐     dlopen allowlisted .so
              │  trance-runner   │────────────────────────────► trance-plugins
              │  wayland-present │
              │  wayland-idle    │
              └──────────────────┘
```

---

## Summary severity counts

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High     | 4 |
| Medium   | 10 |
| Low      | 8 |
| Nit      | 6 |

**Bottom line:** Ship-quality desktop daemon with above-average path and packaging discipline; prioritize unauthenticated ScreenSaver activation, production Preview path resolution, preview FSM correctness, and a control-plane story that does not depend on `/proc/exe` readability under the very hardening flags you enable.
