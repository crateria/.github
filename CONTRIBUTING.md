# Contributing to Crateria

Thanks for your interest. Product work lives in the product repositories:

| Project | Repository |
|---------|------------|
| Screensaver stack | https://github.com/crateria/trance |
| Effects | https://github.com/crateria/trance-plugins |
| Archive tool | https://github.com/crateria/morphball |
| APT/DNF pool | https://github.com/crateria/packages |

## Guidelines

1. Open an issue first for large or cross-repo changes.
2. Branch from `main`; keep commits focused.
3. Run that repo’s CI locally when practical (`cargo test`, `cargo clippy`,
   `cargo deny` where configured).
4. Prefer the canonical package-repo install docs in product READMEs.
5. **Do not** commit secrets, GPG private keys, machine-local paths, or large
   binary pools outside the intentional `packages` release workflow.
6. Security issues: use private vulnerability reporting (see `SECURITY.md`).

## Pull requests

* Target `main`
* Include a short rationale in the PR body
* Sign off commits when required by the org web commit signoff setting
