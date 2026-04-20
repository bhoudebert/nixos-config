# NIXOS

As it is for a personal machine, let's avoid /etc/nixos base config especially if you want any llm to work over the files.

NB: For obvious reason, the github history will be purge from time to time.

## Docs

- [dev.md](./dev.md) - development stack, IDEs, local infra, and shell tooling
- [gaming.md](./gaming.md) - gaming stack, benchmark tools, and when to use them
- [monitoring.md](./monitoring.md) - monitoring stack and dashboard/exporter notes
- [secrets.md](./secrets.md) - agenix workflow, encrypted secrets, and how to consume them
- [issues.md](./issues.md) - issue log and workarounds
- [sound-issue.md](./sound-issue.md) - sound troubleshooting notes

## Home machine

NB: for ease of use & flake design `hardware-configuration.nix` is versioned but be sure to override it post first install.

`sudo nixos-rebuild switch --flake .#home`

For testing file only: `nix --extra-experimental-features 'nix-command flakes' build --print-out-paths '.#nixosConfigurations."home".config.system.build.toplevel' --no-link


## Laptop machine

sudo nixos-rebuild switch --flake .#framework
