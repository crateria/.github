# Crateria agent / maintainer rules

Apply when working in any `crateria/*` repository.

## Org charter

Crateria is **native Linux desktop software in Rust** (Wayland tools, CLI/TUI utilities, signed APT/DNF packages).

- Web/container/Unraid apps → [studio2201](https://github.com/studio2201), not here.
- Default git branch for every repo: **`master`** (only). Do not create or push `main`.

## New product checklist

1. Repo under `crateria/`, Apache-2.0 `LICENSE`, description + topics + homepage.
2. README: install via [crateria.github.io/packages](https://crateria.github.io/packages/), build-from-source, releases, security link, brand link.
3. CI on `master`: `fmt`, `clippy`, `test`, and `cargo deny` where applicable.
4. Copy org policies from `crateria/.github/rust-policies/` (`deny.toml`, `clippy.toml`, `rustfmt.toml`) or run `sync-policies.sh` from a local multi-repo layout.
5. Optional: Release workflow on tags `v*` producing `.deb`/`.rpm`, plus `repository_dispatch` to `crateria/packages` when `CRATERIA_PACKAGES_DISPATCH_TOKEN` is set.
6. Enable private vulnerability reporting on the repo.
7. Add the product to:
   - `crateria/.github` profile `profile/README.md`
   - `crateria/crateria.github.io` site catalog if user-facing
   - `CONTRIBUTING.md` project table

## Release → packages

1. Tag `vX.Y.Z` on product `master`.
2. Product Release workflow uploads assets and may dispatch `new_release` to `crateria/packages`.
3. `packages` **Import Product Release** imports, signs, indexes, deploys Pages.

Secrets:

| Where | Secret | Purpose |
|-------|--------|---------|
| Product repos | `CRATERIA_PACKAGES_DISPATCH_TOKEN` | PAT/fine-grained token that can dispatch workflows on `packages` |
| `packages` | `GPG_PRIVATE_KEY`, passphrase/name as used by import workflow | Sign repo metadata |

## Code style

- Prefer safe Rust; justify `unsafe`.
- Keep modules reviewable (prefer smaller files when a crate grows).
- Match existing CI gates; do not weaken deny/clippy without discussion.

## Do not

- Advertise Docker/GHCR as primary install for desktop daemons.
- Push dual default branches.
- Force-push over unrelated hygiene commits without need.
- File public issues for security bugs — use private vulnerability reporting.

## Phase B hardening (2026-07)

Org-wide 10-agent DAG applied to product crates. Reference model: **morphball**
(full Stages 1–5). **packages** Stages 1–5. **trance-plugins** / **rusting** /
**trance** received bounded Stage 1–style hardening; large remaining unwrap
surfaces (trance daemon, rusting daemon/GUI) are deferred.

Tags of note: `morphball` `v0.1.62`, `packages` `v3.2.29`.
