# Code Review: morphball (crateria/morphball)

**Scope:** `/home/jeryd/Projects/ubermetroid/morphball` — `morphball-core` + `morphball` (CLI/TUI)  
**Version reviewed:** 0.1.39 (workspace crates)  
**Date:** 2026-07-10  
**Method:** Read-only review of source, tests, docs, packaging metadata, and key dependency behavior (zip 2.x, tar 0.4, sevenz-rust2 0.21). No source files were modified.

---

## Overall assessment

Morphball is a small, readable Rust archive toolkit with a sensible crate split (`morphball-core` vs CLI/TUI), real format coverage (zip / 7z / tar.gz), and a non-trivial interactive TUI that already ships in the package metadata. Path hardening for ZIP and tar.gz is present and directionally correct, and 7z extraction inherits `sevenz-rust2`’s own zip-slip checks. That said, the project’s security and performance marketing overshoot the implementation: `rayon` is an unused dependency (no parallel compress/extract), ZIP “encryption” uses cryptographically broken ZipCrypto despite enabling `aes-crypto`, and every CLI pack silently appends a proprietary “reserves” trailer that is undocumented, untested, and risks interop with external tools. More seriously, SFX/cloak/decloak use fixed names under the shared temp directory, SFX auto-extracts into the current working directory on binary launch without confirmation, and `doctor_and_heal` trusts footer fields without bounds checks (panic / DoS on adversarial input). Tests cover only happy-path round-trips for three formats and three trivial `path_safe` unit cases—nowhere near the zip-slip, password, reserves, or SFX claims. Documentation is actively wrong about the TUI (“planned / not shipped”) while the binary, packaging, and `morphball tui` subcommand already exist. Treat this as a promising early prototype, not yet a trustworthy “secure multi-threaded” 7-Zip replacement.

---

## Findings by severity

### Critical

#### C1. Predictable fixed temp files for SFX / cloak / decloak (TOCTOU, data leak, clobber)
**Where:**  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/src/lib.rs` (`chozo_temp.zip`, `chozo_temp_out.zip`, `cloak_temp.zip`, `decloak_temp.zip`)

**Issue:**  
Payloads are written to hard-coded paths under `std::env::temp_dir()` (typically shared `/tmp`). Concurrent morphball instances race on the same names; same-user processes can replace temp content mid-operation; default permissions may leave archive bytes readable by other local users depending on umask; cleanup uses `let _ = remove_file(...)` and can leave secrets on disk after failure.

**Fix guidance:**  
Use `tempfile::NamedTempFile` / `tempfile::TempDir` with random names, restrictive mode (`0o600`), RAII cleanup, and preferably in-memory or pipe-based extraction for SFX so cleartext never hits a shared directory. Never reuse fixed basenames.

#### C2. Self-extracting “Chozo” payload auto-runs and unpacks into CWD without consent
**Where:**  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/src/lib.rs` — `check_and_run_sfx`  
- Called at startup from `/home/jeryd/Projects/ubermetroid/morphball/morphball/src/bin/cli.rs` and `.../bin/tui.rs`

**Issue:**  
Any binary containing the marker + ZIP magic will, on launch, dump archive contents into the **current working directory**, overwriting existing files (`File::create` semantics), with no prompt, no destination choice, no integrity check beyond ZIP parse, and no password support. Combined with “rename / social-engineer a Chozo binary,” this is a classic self-extracting malware delivery pattern. Marker “obfuscation” (XOR 0x5A) is security theater.

**Fix guidance:**  
SFX should be an explicit subcommand/mode, not implicit on every CLI/TUI start—or at minimum require `--auto-extract` / interactive confirmation and extract only to a new subdirectory. Prefer extracting from an embedded reader without temp files. Document threat model clearly.

#### C3. `doctor_and_heal` trusts adversarial footer fields (panic / memory DoS)
**Where:**  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/src/reserves.rs` — `doctor_and_heal`

**Issue:**  
Footer integers (`orig_size`, `block_size`, `group_size`, `num_groups`) are used without validation:

- `bytes[..orig_size]` panics if `orig_size > file_size`
- `payload[payload_cursor..payload_cursor + block_size]` panics on short/corrupt payload
- `blocks[block_idx]` can OOB if `num_blocks_in_group` / `group_size` are inconsistent
- `group_size == 0` yields degenerate indexing
- Entire file is loaded into memory twice-ish (full read + `archive_bytes` clone)

A user running `morphball doctor evil.archive` on untrusted input can crash or OOM the process. For a “self-healing integrity” feature this is inverted threat modeling.

**Fix guidance:**  
Validate all footer fields against `file_size` and payload length before slicing; use `get`/`checked_*` arithmetic; cap `block_size` / `num_groups`; return `MorphballError` instead of panicking; stream rather than full-file clone; re-apply or preserve reserves after heal if that is the product intent.

---

### High

#### H1. ZIP password uses broken ZipCrypto; AES feature enabled but unused
**Where:**  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/src/compress/zip.rs` — `with_deprecated_encryption` via `zip::unstable::write::FileOptionsExt`  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/Cargo.toml` — `zip` features include `aes-crypto`

**Issue:**  
ZipCrypto is known-broken (known-plaintext recovery). The `zip` crate exposes proper `with_aes_encryption`, and the feature is already on, but compression never uses it. README / product language (“Password Encryption”, “Cryptographic support”) implies modern protection.

**Fix guidance:**  
Default to AES-256 (`AesMode::Aes256`) for passworded ZIP; keep ZipCrypto only behind an explicit legacy flag if needed; document algorithm choice; add encrypted round-trip tests for ZIP and 7z.

#### H2. Proprietary “reserves” trailer appended to every CLI pack—undocumented, untested, interop risk
**Where:**  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/src/reserves.rs` — `apply_reserves`  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball/src/bin/cli.rs` (always after pack; errors ignored via `let _ =`)  
- TUI compress path in `/home/jeryd/Projects/ubermetroid/morphball/morphball/src/app_async.rs`  
- Not mentioned in README; integration tests never call it

**Issue:**  
Appending opaque recovery data after a complete archive changes on-disk format. Some consumers tolerate trailing garbage (recent `zip` crate is somewhat lenient); others (strict ZIP/gzip/7z tools, CDNs, validators) may reject or mis-handle files. Errors from `apply_reserves` are swallowed, so users believe packing succeeded while healing metadata may be missing. After a successful heal, reserves are **stripped** and not re-applied.

**Fix guidance:**  
Make reserves opt-in (`--reserves` / separate sidecar file preferred). Never mutate standard formats by default. Surface apply errors. Add round-trip tests: pack→apply→list→extract for each format, plus external-tool smoke tests. Document the footer layout if kept.

#### H3. Zip-slip defenses incomplete (symlink overwrite / pre-existing link following)
**Where:**  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/src/decompress/zip.rs` — `File::create(&outpath)`  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/src/path_safe.rs`

**Issue:**  
Component filtering + `enclosed_name` blocks classic `../` entries (good). They do **not** prevent writing through a pre-existing symlink under `output_dir` that points outside the tree, nor do they use `O_NOFOLLOW` / create-new exclusive opens. Partial extracts leave debris. No ratio/size limits (zip bombs).

**Fix guidance:**  
Before write: `symlink_metadata` reject if symlink; open with `OpenOptions` that do not follow links where platform allows; optionally `canonicalize` base and verify each final path stays under base after parent creation. Add max total uncompressed bytes / max file count. Add adversarial fixture tests (see Testing gaps).

#### H4. Password handling is operationally weak
**Where:**  
- CLI `-p` / `--password` in `/home/jeryd/Projects/ubermetroid/morphball/morphball/src/bin/cli.rs`  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball/src/cli_helpers.rs`  
- Core APIs take `Option<&str>` with no zeroization

**Issue:**  
`-p` places secrets in argv (`/proc/*/cmdline`, shell history). SECURITY.md correctly prefers `-P`, but README demos `-p mypassword`. Passwords live in `String`/`&str` with no `zeroize`/secrecy types. TUI compress/decompress never prompts for passwords at all (always `None`).

**Fix guidance:**  
Deprecate or strongly warn on `-p`; prefer env/`-P` only; use `secrecy`/`zeroize`; clear buffers after use; add TUI password prompt for encrypted archives; never log passwords (currently not logged—keep it that way).

#### H5. Multi-threaded / rayon claims are false
**Where:**  
- README “Multi-threaded Speed… powered by `rayon`”  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/Cargo.toml` depends on `rayon`  
- **Zero** `rayon` / `par_iter` usages in `*.rs`  
- `MorphballError::ThreadPool` unused

**Issue:**  
Compression/extraction is single-threaded. TUI only offloads one job thread and even **sleeps** to pad progress UI to ~3s (`app_async.rs`). This is a material accuracy problem for a performance-positioned tool.

**Fix guidance:**  
Either implement real parallel member compression (where format allows) with rayon, or remove the dependency and rewrite marketing. Dead `ThreadPool` error variant should go until used.

---

### Medium

#### M1. README / docs contradict shipped product (TUI)
**Where:**  
- `/home/jeryd/Projects/ubermetroid/morphball/README.md` — “`morphball-tui` *(planned / not in workspace yet)*”, “not shipped in this repository yet”  
- Reality: `/home/jeryd/Projects/ubermetroid/morphball/morphball/src/bin/tui.rs`, `[[bin]] name = "morphball-tui"`, deb/rpm assets, `morphball tui` subcommand, release binaries under `target/release/`

**Issue:**  
Users and reviewers will mistrust all other security claims if the README is this wrong. Keybind section partially matches the real TUI, but description (“dual-pane explorer”) is only half-true (list + info, not dual filesystem panes).

**Fix guidance:**  
Document `morphball-tui` as shipped: install paths, keys (C/X/Z/H/D/F/Q, `/` search), limitations (no password UI yet). Align architecture bullets with actual crates.

#### M2. Architecture: core is a grab-bag; CLI crate has no `lib.rs`
**Where:**  
- `morphball-core/src/lib.rs` mixes compress API, SFX, stego cloak, format detect helpers, reserves  
- `morphball` uses `#[path = "../..."]` module inclusion from bins instead of a library crate

**Issue:**  
Harder to test CLI helpers, harder to reuse, encourages circular “bin includes sibling files” layout. `run_compress` / `run_decompress` use `unreachable!()` on bad extensions instead of `InvalidFormat`. Dead deps: `rayon`, `zstd` (never referenced in core src), `serde` (unused).

**Fix guidance:**  
Split core modules by concern (`archive`, `sfx`, `stego`, `integrity`). Give `morphball` a small `lib.rs` for shared TUI/CLI logic. Fail closed with errors, not panics. Prune unused deps (`cargo machete` / deny unused).

#### M3. Error handling inconsistency and silent failures
**Where:**  
- Public SFX/cloak/reserves APIs return `Box<dyn Error>` while format code uses `MorphballError`  
- CLI: `let _ = apply_reserves(...)`  
- TUI: `mutex.lock().unwrap()`, status strings discard structured errors  
- `list_archive` ignores password for ZIP entries

**Issue:**  
Callers cannot match error kinds; integrity failures vanish; poisoned mutex kills TUI; encrypted ZIP listing may be incomplete depending on encryption mode.

**Fix guidance:**  
Unify on `MorphballError` (add variants for SFX/cloak/reserves/password). Propagate reserves errors. Prefer `lock().map_err` or recover. Pass password into ZIP list path where applicable.

#### M4. Format correctness gaps
| Format | Gaps |
|--------|------|
| **ZIP** | Empty directories omitted; permissions/symlinks not preserved; ZipCrypto only; no ZIP64 knobs; unstable encryption API |
| **7z** | Thin wrappers around `sevenz-rust2` only; no progress; no solid/level controls; path safety depends entirely on dependency |
| **tar.gz** | Password flag accepted at CLI level but ignored for this format (no error); gzip best only; no other compressors (xz/zstd) despite zstd dep |

**Fix guidance:**  
Reject `-p` for tar.gz with a clear error; preserve empty dirs for ZIP; expose compression level; add 7z progress if library allows; document supported feature matrix honestly vs 7-Zip/WinRAR.

#### M5. “Cloak” is not steganography
**Where:**  
- `cloak_payload` / `decloak_payload` in `lib.rs`

**Issue:**  
Appends marker + ZIP after carrier bytes. Trivially detectable; does not hide data in image entropy; may break some image consumers less than pure append-after-IEND PNG tricks, but still not stego. Marketing language overclaims.

**Fix guidance:**  
Rename to “append payload” / “carrier bundle” or implement real container-aware embedding with tests. Same temp-file fixes as C1.

#### M6. SFX scans and reads entire executable on every invocation
**Where:**  
- `check_and_run_sfx` linear reverse scan of full `current_exe` bytes

**Issue:**  
Startup cost grows with binary size (worse for Chozo artifacts). Full-file read is unnecessary for normal CLI use.

**Fix guidance:**  
Only scan when explicitly in SFX mode, or read a fixed-size tail window; use memory mapping carefully; don’t block normal `pack`/`unpack` on SFX discovery.

#### M7. TUI progress intentionally slows work
**Where:**  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball/src/app_async.rs` — per-file `sleep` and minimum 3s duration

**Issue:**  
Contradicts performance goals; compress/extract of large trees becomes artificially slow.

**Fix guidance:**  
Drive UI from real progress only; remove forced delays (or gate behind a demo flag).

#### M8. Doctor network check uses hard-coded GitHub Pages IP over HTTP:80
**Where:**  
- `/home/jeryd/Projects/ubermetroid/morphball/morphball/src/doctor.rs`

**Issue:**  
Fragile (IP changes), not TLS, not a real health check of archive functions despite final message claiming “All core archive functions ready.”

**Fix guidance:**  
Either remove network probe or HTTPS-resolve hostname; run a real in-process compress/decompress smoke test for diagnostics.

---

### Low

#### L1. `path_safe` unit tests only cover three cases; no Windows `\` normalization
**Where:** `path_safe.rs`  
On Unix, backslash is not a separator—Windows-crafted names relying on `\` are not normalized (unlike `sevenz-rust2`’s `safe_join`). ZIP path mostly relies on `enclosed_name` which helps, but tar uses `entry.path()` + `safe_extract_path` without `\` normalization.

**Fix:** Normalize `\` → `/` before component checks (as sevenz does); expand tests (absolute UNC, `..`, mixed separators, empty, `.`).

#### L2. Partial extraction leaves files behind on mid-archive failure
No transactional extract-to-temp-then-rename. Document or implement staging directory.

#### L3. Overwrite without confirmation  
CLI/TUI extract and SFX overwrite existing files silently.

#### L4. `apply_reserves` / SFX load whole files into `Vec<u8>`  
Memory blow-up on large archives; stream where possible.

#### L5. Workspace `panic = "abort"` in release  
Fine for CLI size; complicates embedding as a library—document.

#### L6. `deny.toml` ignores several RUSTSEC IDs  
Unmaintained crate noise may be OK, but track why and when to remove ignores.

#### L7. Line-budget claim (“functions capped under 250 lines”)  
Clippy `too-many-lines-threshold = 150`; claim is style marketing, not enforced at 250. Several TUI modules are dense UI code.

#### L8. Empty `ThreadPool` / unused imports of capabilities  
Dead API surface suggests unfinished design.

---

### Nit

#### N1. Themed UX strings (“Chozo Artifact”, emoji-heavy status) in core library  
Prefer keeping `println!` out of `morphball-core`; return structured results and let CLI/TUI render.

#### N2. `#[path = ...]` includes instead of normal modules  
Works but confuses rust-analyzer and testing.

#### N3. Integration tests use `unwrap` heavily  
Acceptable in tests; prefer `expect` with context for failures.

#### N4. Version skew in tree  
Package version 0.1.39 vs built deb/rpm artifacts named 0.1.38 in `target/` (build artifact drift only).

#### N5. SECURITY.md is thin  
Good private reporting note; expand with threat model (trusted vs untrusted archives, password guidance, SFX risks).

#### N6. `is_supported_format` vs `detect_format` duplication  
Core vs CLI helper drift risk (e.g. future formats).

---

## Testing gaps vs security / product claims

| Claim / risk area | Current coverage | Gap |
|-------------------|------------------|-----|
| Zip-slip / path traversal | 3 unit tests on `safe_extract_path`; no archive fixtures | Malicious ZIP/7z/tar members (`../`, absolute, `..\\`, nested), symlink pre-seed, extract under weird base paths |
| Password crypto | None | ZIP AES vs ZipCrypto round-trip; wrong password; 7z encrypted; list encrypted |
| Reserves / doctor | None | Apply→open with stock tools; heal single-block corruption; reject multi-block; adversarial footer (C3) |
| SFX / cloak | None | Temp-file race; extract location; marker false positive; concurrent runs |
| Multi-thread correctness | N/A (no parallel impl) | If added: race on shared writers, deterministic archive bytes |
| CLI surface | No CLI tests | clap args, `-P` vs `-p`, unsupported format, tar.gz+password error |
| TUI | None | Key handling, background job failure, passwordless extract of encrypted zip |
| Zip bomb / resource limits | None | Huge ratio / entry count |
| Interop | None | 7z/zip produced by external tools; morphball archives opened by `unzip`/`tar`/`7z` **with reserves on** |

Happy-path only: `/home/jeryd/Projects/ubermetroid/morphball/morphball-core/tests/integration_tests.rs` (zip, tar.gz, 7z content equality).

---

## Architecture notes (`morphball-core` vs `morphball`)

**What works well**
- Clear workspace members; `unsafe_code = "deny"` at workspace level.
- Format code split under `compress/` and `decompress/`.
- Shared `MorphballError` for primary archive operations.
- Packaging already installs both `morphball` and `morphball-tui`.

**What needs structure work**
- Core should be pure library (no SFX auto-print, no doctor UX).
- CLI should own progress bars, password prompts, reserves policy flags.
- TUI should call the same high-level operations as CLI (today TUI bypasses password and reimplements format detection).
- Prefer a public, documented API: `ArchiveFormat`, `PackOptions { password, reserves, level }`, `UnpackOptions { password, overwrite, max_bytes }`.

---

## Doc accuracy checklist

| README / SECURITY claim | Verdict |
|-------------------------|---------|
| Interactive TUI planned / not shipped | **False** — binary and packages exist |
| Dual-pane interactive file explorer | **Partially true** — list + detail, not dual directory panes |
| Multi-threaded / rayon work-stealing | **False** — unused dependency |
| Hardened against zip-slip | **Partially true** — basic component checks; symlink/bomb gaps; uneven across formats |
| Password encryption for ZIP and 7z | **Partial** — 7z OK path; ZIP is ZipCrypto; TUI has no password UX |
| Drop-in for 7zip / winrar / gzip | **Overstated** — limited formats/options; reserves mutate outputs |
| Functions capped under 250 lines | Style claim only; not a hard guarantee |
| Prefer `-P` over CLI passwords (SECURITY.md) | Good guidance; README examples undermine it |

---

## Top 5 recommended next engineering investments

1. **Threat-model untrusted archives and close the critical holes**  
   Fix temp files (C1), make SFX explicit/safe (C2), harden `doctor_and_heal` (C3), and block symlink-following extracts (H3). These are prerequisites for any “secure archive manager” branding.

2. **Add an adversarial + security regression test suite**  
   Fixture archives for zip-slip, symlinks, encrypted round-trips, reserves footer abuse, and CLI integration tests. Gate CI on these before feature work. This is the highest leverage quality investment given current test poverty.

3. **Make format outputs standard by default**  
   Opt-in reserves (or sidecar), switch ZIP encryption to AES, reject meaningless password flags on tar.gz, document a supported feature matrix, and verify interop with `unzip` / `tar` / `7z` in CI.

4. **Align product, docs, and architecture**  
   Rewrite README for the real TUI and honest concurrency story; prune dead deps (`rayon`, `zstd`, `serde` if unused); unify errors on `MorphballError`; stop putting UI side effects in `morphball-core`.

5. **Only then invest in real performance**  
   If multi-core speed is a goal, design parallel member compression where formats allow (ZIP store/deflate members), stream large files, and remove artificial TUI sleeps—backed by benchmarks rather than dependency line items.

---

## Positive notes (keep these)

- Path traversal helper exists and is used for ZIP + tar.gz; 7z dependency performs analogous checks.
- Workspace lints deny `unsafe_code`; Apache-2.0 licensing and SECURITY.md reporting channel are present.
- Clap 7z-style aliases (`a`/`x`/`l`) are ergonomic; progress bars on CLI pack/unpack are a good UX baseline.
- TUI is more complete than docs admit (search, format cycle, background jobs, cloak/chozo hooks)—worth documenting rather than hiding.
- `sevenz-rust2` chosen with AES features is a solid foundation if wrappers stay thin and tested.

---

*End of review. No repository files under `morphball/` were modified; this report was written only to `/home/jeryd/Projects/ubermetroid/CRATERIA_REVIEW_morphball.md`.*
