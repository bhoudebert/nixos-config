# NixOS

This repo keeps the machine configuration in-project instead of in `/etc/nixos`,
which makes it easier to inspect, review, and automate against the actual files.

Git history may be rewritten occasionally because this is a personal machine repo.

## Docs

- [dev.md](./dev.md) - development stack, IDEs, local infra, and shell tooling
- [gaming.md](./gaming.md) - gaming stack, benchmark tools, and when to use them
- [monitoring.md](./monitoring.md) - monitoring stack and dashboard/exporter notes
- [npm-global-tools.md](./npm-global-tools.md) - npm global CLI setup on NixOS and why `~/.local` is used
- [secrets.md](./secrets.md) - agenix workflow, encrypted secrets, and how to consume them
- [issues.md](./issues.md) - issue log and workarounds
- [sound-issue.md](./sound-issue.md) - sound troubleshooting notes

## Encrypted Data

The `.age` files currently committed in `secrets/` are personal encrypted data,
not generic defaults.

If you clone this repo for another machine or another person, you will
not be able to use them as-is: those `.age` files are encrypted for my
private key. Replace or rekey them with your own values and your own
public keys.

Current examples:

- `secrets/grafana-secret-key.age` - local Grafana secret for the monitoring stack
- `secrets/dev-private-hosts.age` - optional private `/etc/hosts` additions for development

Relevant docs:

- [secrets.md](./secrets.md) - how to create, edit, rotate, and rekey `.age` files
- [monitoring.md](./monitoring.md) - why Grafana needs its own secret
- [dev.md](./dev.md) - how encrypted private host aliases are merged into `/etc/hosts`

## Host

`hosts/home/hardware-configuration.nix` is versioned for convenience, but it is
still generated host-specific state. Re-check it after first install or major
hardware changes.

`sudo nixos-rebuild switch --flake .#home`

When a rebuild changes critical components such as DBus, prefer the safe path:

```bash
sudo nixos-rebuild boot --flake .#home
sudo reboot
```

## Layout

The repo now follows a more dendritic NixOS layout:

- `hosts/home/` contains the host entrypoint and host-specific hardware leaf
- `modules/nixos/core/` contains the shared machine trunk: boot, locale, users, desktop baseline, secrets, and Home Manager glue
- `modules/nixos/profiles/` contains feature branches such as `dev`, `gaming`, `monitoring`, and `desktop/hyprland`, each split into system and Home Manager leaves where useful

Private local host aliases can live in the encrypted
`secrets/dev-private-hosts.age`. If present, the same rebuild command will
merge them into `/etc/hosts`.

For evaluation-only testing:

```bash
nix --extra-experimental-features 'nix-command flakes' build \
  --print-out-paths '.#nixosConfigurations."home".config.system.build.toplevel' \
  --no-link
```

## Windows

A useful command, that you would need to adapt, to get your windows disk available:

```shell
sudo mkdir -p /mnt/windows && sudo mount -t ntfs3 -o ro,force,uid=$(id -u),gid=$(id -g) /dev/sda3 /mnt/windows && ls /mnt/windows
```

## Extra

At the moment there is a little try for me on helium, so it is packaged from directly github and can be used through the following command: `nix run .#helium`

## Cleaning

It is very important to clean from time to time your nix installation especially if you bump a lot the deps using `nix flake update`. If you could earn gigabytes, but be aware that it will delete old generation of system.

```shell
sudo nix-collect-garbage -d
nix-store --optimise
```