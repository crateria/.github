# Crateria

<p align="center">
  <img src="icons/crateria.png" width="96" height="96" alt="Crateria">
</p>

<p align="center">
  Linux desktop software written in Rust.<br>
  Wayland tools, signed package repositories, and small focused utilities.
</p>

## Projects

| | Project | Description |
|---|---------|-------------|
| <img src="icons/trance.png" width="40" height="40" alt=""> | **[trance](https://github.com/crateria/trance)** | Wayland screensaver daemon (CLI, TUI, optional COSMIC applet) |
| <img src="icons/trance-plugins.png" width="40" height="40" alt=""> | **[trance-plugins](https://github.com/crateria/trance-plugins)** | Official screensaver effects |
| <img src="icons/morphball.png" width="40" height="40" alt=""> | **[morphball](https://github.com/crateria/morphball)** | Archive manager (CLI + TUI) with path-traversal checks |
| <img src="icons/crateria.png" width="40" height="40" alt=""> | **[packages](https://github.com/crateria/packages)** | APT and DNF repositories |

Organization map: [crateria/crateria](https://github.com/crateria/crateria) · Brand assets: [crateria/brand](https://github.com/crateria/brand)

## Install

Add the package repository once, then install with your distro tools.

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

- Contributing: [CONTRIBUTING.md](../CONTRIBUTING.md)
- Security policy: [SECURITY.md](../SECURITY.md)
- Prefer private vulnerability reporting on the affected product repository
