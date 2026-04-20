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

## Personal Encrypted Data

The `.age` files currently committed in `secrets/` are **mine's**
encrypted data, not generic defaults.

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

## Home machine

NB: for ease of use & flake design `hardware-configuration.nix` is versioned but be sure to override it post first install.

`sudo nixos-rebuild switch --flake .#home`

Private local host aliases can live in the encrypted
`secrets/dev-private-hosts.age`. If present, the same rebuild command will
merge them into `/etc/hosts`.

For testing file only: `nix --extra-experimental-features 'nix-command flakes' build --print-out-paths '.#nixosConfigurations."home".config.system.build.toplevel' --no-link


## Laptop machine

sudo nixos-rebuild switch --flake .#framework
