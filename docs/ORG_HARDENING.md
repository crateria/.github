# Org hardening log (2026-07-11)

## Applied

1. Secret scanning + push protection + Dependabot security updates on all repos
2. Private vulnerability reporting on product repos
3. Branch protection on product `main`: no force-push, no branch deletion
4. De-personalized `packages/sign_all.sh` (`CRATERIA_GPG_*` env)
5. `packages/docs/SIGNING.md` ceremony + compromise response
6. CODEOWNERS / issue+PR templates on packages; CODEOWNERS elsewhere as needed
7. Org profile + SECURITY/CONTRIBUTING refresh

## Still manual

* Toggle **Require 2FA** in org Authentication security settings if API remains no-op
* Optional: required CI status checks after workflows are green
* Optional: Dependabot PR backlog cleanup on trance (duplicate major bumps)

## Brand policy

* Public: **Crateria**
* Legacy D-Bus: `io.github.ubermetroid.trance` until migration
