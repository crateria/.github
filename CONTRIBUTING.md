# Contributing to Crateria

Thanks for helping with Crateria — Linux desktop software written in Rust.

## Projects

| Repository | Role |
|------------|------|
| [trance](https://github.com/crateria/trance) | Wayland screensaver daemon |
| [trance-plugins](https://github.com/crateria/trance-plugins) | Official Trance effects |
| [morphball](https://github.com/crateria/morphball) | Secure archive manager (CLI + TUI) |
| [packages](https://github.com/crateria/packages) | APT and DNF package repositories |
| [rusting](https://github.com/crateria/rusting) | Experimental Syncthing-compatible client |
| [brand](https://github.com/crateria/brand) | Brand kit |

## How to contribute

1. Open an issue (or pick an existing one) before large changes.
2. Fork the product repository and create a focused branch.
3. Keep changes small; prefer readable Rust over cleverness.
4. Run the project’s usual checks (`cargo fmt`, `cargo clippy`, `cargo test`).
5. Open a pull request against the default branch with a clear summary.

## Code style

- Prefer safe Rust; document any `unsafe` with a short justification.
- Keep modules cohesive; split large files when they become hard to review.
- Match existing naming, layout, and CI expectations in that repo.

## Security

Do **not** open public issues for sensitive vulnerabilities. See [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the
Apache License 2.0 (see each product repository’s `LICENSE`).
