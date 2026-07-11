# Crateria security checklist (org)

## Enabled via API (current)

- [x] Secret scanning on all public repos
- [x] Secret scanning push protection on all public repos
- [x] Dependabot security updates (repos)
- [x] Dependabot alerts / updates / dependency graph defaults for **new** repos
- [x] Secret scanning defaults for **new** repos
- [x] Pull requests enabled on all product repos

## Requires owner action in GitHub UI

- [ ] **Require 2FA** for organization members  
  Settings → Authentication security → Require two-factor authentication  
  https://github.com/organizations/crateria/settings/security
- [ ] **Private vulnerability reporting** per repo (if not already on)  
  Each repo → Settings → Code security → Private vulnerability reporting
- [ ] Optional: branch protection on `main` (required checks: CI / Security advisories)
- [ ] Optional: publish member list if you want public attribution

## Notes

- D-Bus bus name for trance remains `io.github.ubermetroid.trance` for upgrade compatibility.
- Package Maintainer strings in APT indexes refresh on the next `update.sh` publish after Cargo metadata changes.
