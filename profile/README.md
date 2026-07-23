<p align="center">
  <img src="crateria-header.jpg" alt="Crateria" width="100%">
</p>

# Crateria

Linux desktop software written in Rust. Wayland tools, signed package
repositories, and small focused utilities.

Self-hosted **web** apps and Unraid templates live under
[studio2201](https://github.com/studio2201).

## Projects

| Project | CI | Description |
|---------|:--:|-------------|
| **[trance](https://github.com/crateria/trance)** | [![CI](https://github.com/crateria/trance/actions/workflows/ci.yml/badge.svg)](https://github.com/crateria/trance/actions/workflows/ci.yml) | Wayland screensaver daemon (CLI, TUI, optional COSMIC applet) |
| **[trance-plugins](https://github.com/crateria/trance-plugins)** | [![CI](https://github.com/crateria/trance-plugins/actions/workflows/ci.yml/badge.svg)](https://github.com/crateria/trance-plugins/actions/workflows/ci.yml) | Official screensaver effects |
| **[morphball](https://github.com/crateria/morphball)** | [![CI](https://github.com/crateria/morphball/actions/workflows/ci.yml/badge.svg)](https://github.com/crateria/morphball/actions/workflows/ci.yml) | Secure archive manager (CLI + TUI) |
| **[packages](https://github.com/crateria/packages)** | [![CI](https://github.com/crateria/packages/actions/workflows/ci.yml/badge.svg)](https://github.com/crateria/packages/actions/workflows/ci.yml) | APT and DNF package repositories |
| **[rusting](https://github.com/crateria/rusting)** | — | Experimental Syncthing-compatible client (**WIP**) |

Brand kit: [crateria/brand](https://github.com/crateria/brand) · Site: [crateria.github.io](https://crateria.github.io/) · Maintainer notes: [AGENTS.md](https://github.com/crateria/.github/blob/master/AGENTS.md)

## Install

<details>
<summary><strong>Debian / Ubuntu / Pop!_OS</strong></summary>

```bash
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://crateria.github.io/packages/apt/crateria-keyring.gpg \
  -o /etc/apt/keyrings/crateria.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/crateria.gpg] https://crateria.github.io/packages/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/crateria.list
sudo apt update
sudo apt install trance   # or: morphball
```

</details>

<details>
<summary><strong>Fedora</strong></summary>

```bash
sudo curl -fsSL https://crateria.github.io/packages/rpm/crateria.repo \
  -o /etc/yum.repos.d/crateria.repo
sudo dnf install trance   # or: morphball
```

</details>

Package index: [crateria.github.io/packages](https://crateria.github.io/packages/)

## Community

- [CONTRIBUTING.md](https://github.com/crateria/.github/blob/master/CONTRIBUTING.md)
- [SECURITY.md](https://github.com/crateria/.github/blob/master/SECURITY.md)
- [AGENTS.md](https://github.com/crateria/.github/blob/master/AGENTS.md) — checklist for maintainers and coding agents
