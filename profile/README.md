<p align="center">
  <img src="crateria-header.jpg" alt="Crateria" width="100%">
</p>

# Crateria

Linux desktop software written in Rust. Wayland tools, signed package
repositories, and small focused utilities.

## Projects

| Project | Description |
|---------|-------------|
| **[trance](https://github.com/crateria/trance)** | Wayland screensaver daemon (CLI, TUI, optional COSMIC applet) |
| **[trance-plugins](https://github.com/crateria/trance-plugins)** | Official screensaver effects |
| **[morphball](https://github.com/crateria/morphball)** | Archive manager (CLI + TUI) |
| **[packages](https://github.com/crateria/packages)** | APT and DNF repositories |

Organization map: [crateria/crateria](https://github.com/crateria/crateria) · Brand: [crateria/brand](https://github.com/crateria/brand)

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

## Contributing and security

- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [SECURITY.md](../SECURITY.md)
