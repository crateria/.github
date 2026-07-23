# Trance rename and new-org transfer runbook

**Status:** Research support only. Do **not** execute renames until the product
name and GitHub organization login are chosen.

**Date:** 2026-07-23  
**Current home:** `github.com/crateria/trance` + `crateria/trance-plugins`  
**Current default branch:** `master`

---

## Decisions you must lock before cutover

| Decision | Options / notes |
|----------|-----------------|
| **New product name** | Display name + binary names (`trance` CLI today) |
| **New org login** | Must be free on GitHub (user+org namespace) |
| **Repo layout** | Two repos (daemon + plugins) vs monorepo |
| **Package names** | Keep `trance*` for APT/DNF stability vs rename packages (breaks upgrades) |
| **D-Bus API** | Keep `io.github.crateria.trance` forever vs break clients |
| **Crateria role after move** | Studio umbrella vs sunset desktop brand |

Recommendation if you want zero upgrade pain: **rename GitHub org/repos for humans**, keep **deb/rpm package names and D-Bus names** stable until a major version.

---

## Cutover sequence (when ready)

1. Create empty org (or use existing free login).
2. Transfer `trance` and `trance-plugins` (Settings → Transfer, or `gh api`).
3. GitHub serves redirects from `crateria/*` for a long time; update canonical URLs anyway.
4. Run string replace inventory below; open one PR per repo (or monorepo).
5. Rebuild and publish packages; update `crateria/packages` **or** move package hub under the new org.
6. Update `crateria` profile/site to link the new home (or remove product rows).
7. Smoke: install from packages, `trance-cli status`, plugin preview, D-Bus if used.
8. Optional: archive empty stubs / update topics.

---

## String / artifact inventory

### GitHub / clone URLs

| String | Where it appears |
|--------|------------------|
| `github.com/crateria/trance` | READMEs, badges, docs, Homepage fields |
| `github.com/crateria/trance-plugins` | READMEs, CI clone sibling, docs |
| `git clone …/crateria/trance.git` | Build-from-source docs |
| `branch = "main"` in plugin docs | `trance/docs/creating_plugins.md` still says `main` — fix to `master` or new default |
| Actions badges | `…/crateria/trance/actions/…` |
| Security advisory URLs | `…/crateria/trance/security/…` |

### Cargo crate / package names (high blast radius)

| Name | Location |
|------|----------|
| `trance-api`, `trance-daemon`, `trance-cli`, `trance-tui`, `trance-applet`, `trance-dbus`, `trance-ipc`, `trance-runner`, `trance-upscaler`, `trance-plugins-all` | `trance/**/Cargo.toml` |
| `trance-plugin-*` (beams, bursts, …) | `trance-plugins/**/Cargo.toml` |
| Path deps on sibling `../trance` | CI workflows in `trance-plugins` |

Renaming crates forces every `use trance_*` import and deb package rename. Prefer **repo rename without crate rename** for v1 cutover.

### Debian / RPM package names (upgrade surface)

Published today under Crateria packages (see `packages/apt/.../Packages`):

- `trance`, `trance-cli`, `trance-tui`, `trance-applet`
- `trance-plugin-*`, `trance-plugins-all`

If package names change, document a transitional `Provides:`/`Replaces:` or a one-shot migration note.

### D-Bus / runtime paths

| Constant | Value (today) |
|----------|----------------|
| Object path | `/io/github/crateria/trance` (`trance-dbus`) |
| Service name | Confirm in daemon registration (`io.github.crateria.trance` family) |

Changing these breaks existing desktop integrations. Treat as **ABI**.

### Brand / site / org meta

| Surface | Action on cutover |
|---------|-------------------|
| `crateria/.github` profile | Point Desktop product to new org or remove |
| `crateria.github.io` | Update product links and install examples |
| `crateria/packages` | Either keep hosting packages for the app, or transfer/rebuild under new org |
| `crateria/brand` | Stay with studio or fork assets |

### CI / secrets

| Item | Note |
|------|------|
| `CRATERIA_PACKAGES_DISPATCH_TOKEN` | Must exist on product repos that publish packages |
| `packages` GPG secrets | Stay on whichever org owns the package index |
| Workflow `branches: [master]` | Keep consistent after transfer |
| `git clone …/crateria/trance` in plugins CI | Change to new org URL |

### License copyright line

| File | Today |
|------|-------|
| `trance/LICENSE`, `trance-plugins/LICENSE` | Still says `Copyright 2026 studio2201` in appendix — update to product/org legal name when rebranding |

---

## Suggested minimal vs full rename

### Minimal (recommended first cut)

- New org + transfer repos as-is (`…/trance`, `…/trance-plugins`)
- Update **human URLs** and org profile only
- Keep crate names, deb names, D-Bus IDs
- Crateria remains package + brand host **or** only a pointer page

### Full rebrand (major version)

- Rename crates, binaries, packages, D-Bus
- Coordinated `v1.0.0` (or next major) with migration doc
- Expect Broken clones, plugin rebuilds, and package conflicts

---

## Monorepo option

If plugins move into `trance` workspace:

1. Merge git histories or subtree `trance-plugins` into `plugins/`
2. Single release tags produce daemon + plugin debs
3. Delete or archive `trance-plugins` after redirects
4. Update packages meta package `trance-plugins-all` build path

---

## Pre-flight checklist (run when names are known)

```text
[ ] New org created; billing/permissions OK
[ ] New display name + binary decision recorded
[ ] Package name strategy: keep trance* OR rename with Replaces
[ ] D-Bus: keep or break (document)
[ ] Transfer both repos (or monorepo first)
[ ] URL/badge/docs PR
[ ] CI sibling clone URL
[ ] packages dispatch still works
[ ] Live install smoke on Debian + Fedora
[ ] Crateria profile no longer claims deleted products
[ ] LICENSE copyright updated
```

---

## What this runbook deliberately does not do

- Choose the new org or product name
- Execute `gh` transfers
- Rename crates in-tree

When names are final, hand this file to an agent with:  
`NEW_ORG=… NEW_REPO=… KEEP_PACKAGE_NAMES=yes|no KEEP_DBUS=yes|no`
