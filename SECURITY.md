# Security policy

Crateria takes security reports seriously. Report vulnerabilities **privately**
when possible so we can fix them before public disclosure.

## Where to report

Use **private vulnerability reporting** on the repository that owns the code:

| Repository | Scope |
|------------|--------|
| [trance](https://github.com/crateria/trance/security/advisories/new) | Screensaver daemon, CLI, TUI, applet, D-Bus, plugin loading |
| [trance-plugins](https://github.com/crateria/trance-plugins/security/advisories/new) | Official effect plugins |
| [morphball](https://github.com/crateria/morphball/security/advisories/new) | Archive pack/unpack, path safety, SFX |
| [packages](https://github.com/crateria/packages/security/advisories/new) | Package indexes, signing, published artifacts |

If you are unsure which repository applies, open a private report on
[trance](https://github.com/crateria/trance/security/advisories/new) or email
the maintainer through GitHub.

Do **not** open a public issue for active exploits, key compromise, or
malicious packages in the distribution pool.

## Response targets

| Severity | Target |
|----------|--------|
| Acknowledgement | Within 72 hours |
| Critical fix or mitigation | Within 30 days when feasible |

We may ask for more detail or a minimal reproduction. Coordinated disclosure is
preferred until a fix or mitigation is available.

## Package distribution

Users install packages from [crateria.github.io/packages](https://crateria.github.io/packages/).
Packages are GPG-signed. Maintainer signing procedure:
[packages/docs/SIGNING.md](https://github.com/crateria/packages/blob/main/docs/SIGNING.md).

Never commit private keys, passphrases, or machine-local signing paths to any
Crateria repository.

## Compatibility note

Public branding uses **Crateria** (`github.com/crateria`). Some installed
interfaces (for example the trance D-Bus name `io.github.ubermetroid.trance`)
retain older identifiers for upgrade compatibility until a deliberate migration.
