# WSL (Ubuntu on Windows)

Standalone Home Manager home for an Ubuntu WSL2 distro with a single-user Nix
install. It is exposed by the flake as `homeConfigurations.wsl` and targets the
`ben` user (`hosts/wsl/home-manager.nix`).

It reuses the dev profile's Git, mise and Zsh settings, and the shared package
list (`modules/nixos/profiles/dev/packages.nix`) with `withGui = false`:
terminal tools only. No VS Code, JetBrains, DBeaver or Postman from Nix. The
Rust toolchain from the AI profile is included. The Android SDK, Ollama,
libvirt and privoxy parts of the NixOS profiles are not.

## First switch

Flakes are not enabled until this config is active, so pass them explicitly
once:

```bash
cd ~/wks/nixos-config
nix --extra-experimental-features 'nix-command flakes' \
  run home-manager -- switch -b backup --flake .#wsl
```

After that:

```bash
home-manager switch --flake .#wsl
```

The channel-based `~/.config/home-manager/home.nix` created by the Home
Manager installer is no longer used. You can delete it, and remove the
`home-manager` channel with `nix-channel --remove home-manager`.

Make zsh the login shell (Ubuntu's `/usr/bin/zsh`; Home Manager owns
`~/.zshrc`):

```bash
chsh -s /usr/bin/zsh
```

The agnoster prompt needs a Powerline/Nerd font in Windows Terminal, for
example "CaskaydiaCove Nerd Font" or "JetBrainsMono Nerd Font", installed on
the Windows side.

## Windows integration

- **Editor**: VS Code runs on Windows. `code .` from WSL opens it through the
  Remote - WSL extension.
- **Browser**: `BROWSER=wslview`. `wslview` is a small script in this module,
  because `wslu` was removed from nixpkgs. It opens URLs and Linux paths with
  the Windows default app. `open <path|url>` is an alias for it.
- **Docker**: the engine comes from Ubuntu's `docker-ce` packages with systemd
  (`/etc/wsl.conf` has `[boot] systemd=true`), and the user is in the `docker`
  group. The Nix docker CLIs are therefore skipped (`withDockerCli = false`).
  `lazydocker` is installed.
- **Claude Code** is installed natively under `~/.local/bin`, so the shared
  `claude = nix run ...` alias is dropped on this host.

## Notes

- Git identity comes from the shared dev profile (`user.email`). Override it
  per repository, or in this module, if work repositories need another address.
- Keep repositories under the Linux filesystem (`~/wks`), not `/mnt/c`, for
  file watching and I/O speed.
- `home.stateVersion = "26.05"` matches the first Home Manager activation on
  this distro; do not bump it on upgrades.
