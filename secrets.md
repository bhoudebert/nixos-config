# Secrets (`agenix`)

This repo keeps secrets encrypted in git with `agenix` and only decrypts
them locally at activation time.

Current pieces:

- `flake.nix` imports the `agenix` NixOS module and installs the `agenix`
  CLI.
- `secrets/*.age` contains the encrypted payloads committed to git.
- NixOS modules declare `age.secrets.<name>.file = ../../../../secrets/<name>.age;`
- Consumers read the runtime path from `config.age.secrets.<name>.path`,
  which defaults to `/run/agenix/<name>`.

On this machine, `agenix` uses:

```nix
age.identityPaths = [ "/home/bhoudebert/.ssh/id_ed25519" ];
```

So the corresponding local private key is allowed to decrypt and
re-encrypt the repo secrets that reference it.

## How It Works

The important split is:

- git stores only the encrypted `.age` file
- activation decrypts it locally into `/run/agenix/...`
- services read that runtime file, not the git-tracked encrypted blob

That keeps plaintext out of the Nix store and out of the repository.

## Files In This Repo

Example for Grafana:

```nix
age.secrets.grafana-secret-key = {
  file = ../secrets/grafana-secret-key.age;
  owner = "grafana";
  group = "grafana";
  mode = "0400";
};
```

Then the service consumes the decrypted file:

```nix
services.grafana.settings.security.secret_key =
  "$__file{${config.age.secrets.grafana-secret-key.path}}";
```

`$__file{...}` is a Grafana feature: Grafana reads the value from the
file instead of expecting the secret inline in `grafana.ini`.

Another example in this repo is `secrets/dev-private-hosts.age`, which can
hold private `/etc/hosts` lines such as:

```text
127.0.0.1 kafka
127.0.0.1 internal-api
```

The dev profile appends those decrypted lines into `/etc/hosts` during
activation when that optional secret exists.

## Create A New Secret

1. Create or edit the encrypted file:

```bash
agenix -e secrets/my-service-token.age -i /home/bhoudebert/.ssh/id_ed25519
```

If `agenix` is not installed yet, the flake-based fallback is:

```bash
nix run github:ryantm/agenix -- -e secrets/my-service-token.age -i /home/bhoudebert/.ssh/id_ed25519
```

2. Declare it in NixOS:

```nix
age.secrets.my-service-token.file = ../../../../secrets/my-service-token.age;
```

3. Load it from the runtime path:

```nix
systemd.services.my-service.environment.MY_SERVICE_TOKEN_FILE =
  config.age.secrets.my-service-token.path;
```

Or for services that support `passwordFile` / `secretFile` style options:

```nix
services.some-service.passwordFile = config.age.secrets.my-service-token.path;
```

4. Track the encrypted file in git:

```bash
git add secrets/my-service-token.age
```

This matters with flakes: Nix only sees files that are tracked by git.

## Change A Secret Value

To rotate a secret, edit the same `.age` file:

```bash
agenix -e secrets/grafana-secret-key.age -i /home/bhoudebert/.ssh/id_ed25519
```

Save the new plaintext in the editor, then rebuild:

```bash
sudo nixos-rebuild switch --flake .#home
```

Use this when the secret content changes but the allowed recipients stay
the same.

## Read A Secret Manually

For debugging only:

```bash
agenix -d secrets/grafana-secret-key.age -i /home/bhoudebert/.ssh/id_ed25519
```

Prefer reading the runtime file only when needed:

```bash
sudo cat /run/agenix/grafana-secret-key
```

Do not paste decrypted secrets into docs, commit messages, shell
history, or config files.

## Practical Rules

- Put only encrypted `.age` files in git, never plaintext secret files.
- Consume secrets through `config.age.secrets.<name>.path` whenever the
  target service supports file-based secret loading.
- Rotate a secret with `agenix -e`.
- Rekey recipients with `agenix --rekey`.
- Rebuild after secret changes so the service gets the new runtime file.
