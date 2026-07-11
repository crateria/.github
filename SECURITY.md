# Crateria organization security

Report product-specific issues on that product’s repository. Use private
vulnerability reporting when the issue is security-sensitive.

| Repository | Private reporting |
|------------|-------------------|
| [trance](https://github.com/crateria/trance/security/advisories/new) | Yes |
| [trance-plugins](https://github.com/crateria/trance-plugins/security/advisories/new) | Yes |
| [morphball](https://github.com/crateria/morphball/security/advisories/new) | Yes |
| [packages](https://github.com/crateria/packages/security/advisories/new) | Yes (signing / pool) |

## Org checklist

### Automated / API-applied

- [x] Secret scanning on all public repos
- [x] Secret scanning push protection on all public repos
- [x] Dependabot security updates enabled on all public repos
- [x] Dependabot alerts / dependency graph defaults for **new** repos
- [x] Secret scanning defaults for **new** repos
- [x] Private vulnerability reporting enabled on product repos
- [x] Branch protection on product `main`: block force-push and branch deletion
- [x] Web commit signoff required (org setting)

### Applied (owner completed)

- [x] **Require 2FA** for organization members (`two_factor_requirement_enabled: true`)
- [x] Personal account uses secure 2FA methods (SMS removed; TOTP/passkey)
- [ ] Optional: required status checks on `main` once CI is stable
- [ ] Optional: signing key offline backup + rotation drill (`packages/docs/SIGNING.md`)

## Package supply chain

* Consumers install from **https://crateria.github.io/packages/**
* Signing procedure: [packages/docs/SIGNING.md](https://github.com/crateria/packages/blob/main/docs/SIGNING.md)
* Signing scripts must not hardcode personal home paths or emails; use
  `CRATERIA_GPG_NAME` (and optional `CRATERIA_GPG_PATH`)

## Brand / compatibility notes

* Public brand is **Crateria** (`github.com/crateria`).
* Trance D-Bus well-known name remains `io.github.ubermetroid.trance` for
  upgrade compatibility until an explicit migration ships.
* Prefer `crateria` in new public IDs (docs, package names, homepages).

## Response targets

* Acknowledge security reports within **72 hours**
* Critical issues: aim for fix or mitigation within **30 days**
