# Secrets (`agenix`)

This repo keeps secrets encrypted in git with `agenix` and only decrypts
them locally at activation time.

Current pieces:

- `flake.nix` imports the `agenix` NixOS module and installs the `agenix`
  CLI.
- `secrets.nix` declares which public keys can decrypt each secret.
- `secrets/*.age` contains the encrypted payloads committed to git.
- NixOS config declares `age.secrets.<name>.file = ../secrets/<name>.age;`
- Consumers read the runtime path from `config.age.secrets.<name>.path`,
  which defaults to `/run/agenix/<name>`.

On this machine, `agenix` uses:

```nix
age.identityPaths = [ "/home/bhoudebert/.ssh/id_ed25519" ];
```

So the corresponding public key in `secrets.nix` is allowed to decrypt
and re-encrypt the repo secrets.

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

`dev.nix` appends those decrypted lines into `/etc/hosts` during
activation when that optional secret exists.

## Create A New Secret

1. Add a rule to `secrets.nix`.

```nix
let
  bhoudebert = "ssh-ed25519 ...";
in
{
  "secrets/my-service-token.age" = {
    publicKeys = [ bhoudebert ];
    armor = true;
  };
}
```

2. Create or edit the encrypted file:

```bash
agenix -e secrets/my-service-token.age -i /home/bhoudebert/.ssh/id_ed25519
```

If `agenix` is not installed yet, the flake-based fallback is:

```bash
nix run github:ryantm/agenix -- -e secrets/my-service-token.age -i /home/bhoudebert/.ssh/id_ed25519
```

3. Declare it in NixOS:

```nix
age.secrets.my-service-token.file = ../secrets/my-service-token.age;
```

4. Load it from the runtime path:

```nix
systemd.services.my-service.environment.MY_SERVICE_TOKEN_FILE =
  config.age.secrets.my-service-token.path;
```

Or for services that support `passwordFile` / `secretFile` style options:

```nix
services.some-service.passwordFile = config.age.secrets.my-service-token.path;
```

5. Track the encrypted file in git:

```bash
git add secrets/my-service-token.age secrets.nix
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

## Change Who Can Decrypt

If you add or remove recipient public keys in `secrets.nix`, rekey:

```bash
agenix --rekey -i /home/bhoudebert/.ssh/id_ed25519
```

Use this when:

- a new machine should be able to decrypt
- an old key should lose access
- you replaced your SSH key

`rekey` changes the recipients of the encrypted file. It does not change
the secret content.

### Example: Add A New Public Key

Adding the key to `secrets.nix` alone does nothing yet. Existing `.age`
files stay encrypted for their old recipient set until you rekey them.

Typical flow:

1. Add the new public key in `secrets.nix`.
2. Add that key to the relevant secret's `publicKeys` list.
3. Run:

```bash
agenix --rekey -i /home/bhoudebert/.ssh/id_ed25519
```

4. Stage both the rules file and the rewritten encrypted files:

```bash
git add secrets.nix secrets/*.age
```

5. Commit and rebuild on the target machine as usual.

After that, anyone or any machine holding the matching private key can
decrypt the affected secret during activation.

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

## About `armor = true`

In `secrets.nix`, this repo uses:

```nix
armor = true;
```

That makes agenix write the secret as ASCII-armored age text instead of
binary age output.

Practical effect:

- easier to diff in git
- easier to copy around safely as text
- immediately obvious that the file is encrypted
- slightly larger than binary output

If you do not care about readable text diffs, you can omit `armor` and
use binary `.age` files.

## Practical Rules

- Put only encrypted `.age` files in git, never plaintext secret files.
- Consume secrets through `config.age.secrets.<name>.path` whenever the
  target service supports file-based secret loading.
- Rotate a secret with `agenix -e`.
- Rekey recipients with `agenix --rekey`.
- Rebuild after secret changes so the service gets the new runtime file.
