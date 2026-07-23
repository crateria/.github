# Crateria agent / maintainer rules

Apply when working in any `crateria/*` repository.

## Org charter

Crateria is **native Linux desktop software in Rust**, currently focused on the
**Trance** Wayland screensaver family and its signed package distribution.

- Web/container/Unraid apps → [studio2201](https://github.com/studio2201), not here.
- Default git branch for every repo: **`master`** (only). Do not create or push `main`.
- Product renames / org moves for Trance: follow
  [docs/TRANCE_RENAME_TRANSFER.md](docs/TRANCE_RENAME_TRANSFER.md) — do not rename without explicit go-ahead.

## Active product set

| Repository | Role |
|------------|------|
| `trance` | Screensaver daemon, CLI, TUI, applet |
| `trance-plugins` | Official visualizer plugins |
| `packages` | APT/DNF index + Pages |
| `brand` | Brand kit |
| `crateria.github.io` | Docs site |
| `.github` | Profile + community health |

Deleted products (**morphball**, **rusting**) must not reappear in profiles, install docs, or package pools.

## New product checklist

1. Repo under `crateria/` (or future product org), Apache-2.0 `LICENSE`, description + topics + homepage.
2. README: install via [crateria.github.io/packages](https://crateria.github.io/packages/), build-from-source, releases, security link, brand link.
3. CI on `master`: `fmt`, `clippy`, `test`, and `cargo deny` where applicable.
4. Copy org policies from `rust-policies/` or run `sync-policies.sh`.
5. Optional: Release on tags `v*` → dispatch `new_release` to `packages` when `CRATERIA_PACKAGES_DISPATCH_TOKEN` is set.
6. Enable private vulnerability reporting.
7. Add the product to profile, site catalog, and CONTRIBUTING.

## Release → packages

1. Tag `vX.Y.Z` on product `master`.
2. Product Release workflow uploads assets and may dispatch `new_release` to `packages`.
3. `packages` Import workflow indexes and deploys Pages.

## Do not

- Advertise Docker/GHCR as primary install for desktop daemons.
- Push dual default branches.
- Force-push over unrelated hygiene commits without need.
- File public issues for security bugs — use private vulnerability reporting.
- Reintroduce deleted products (morphball, rusting) without an explicit restore decision.
