# Development Stack (`dev.nix`)

This module groups together development tooling that is useful on a
workstation but is not part of the base operating system.

The idea is the same as `gaming.nix`:

- keep `configuration.nix` focused on machine and desktop basics
- keep `dev.nix` focused on source control, editors, local infra, and
  developer-facing utilities

## What Lives Here

`dev.nix` currently owns:

- Git configuration and aliases
- developer shell setup in `zsh`
- Docker / libvirt / virt-manager
- a template for private host aliases kept outside the public repo
- IDEs, editors, API clients, database clients
- Nix helper tools and CLI utilities used during development

## Main Areas

### Git

Home Manager enables `programs.git` with:

- user identity
- a default branch
- short aliases for status, logs, diffs, and pushing

This is the "global developer muscle memory" section.

### Shell

`programs.zsh` in this module is the interactive development shell:

- `direnv` hook for project-local environments
- git/docker/ripgrep-oriented Oh My Zsh plugins
- aliases like `ll` and `claude`
- `$HOME/.local/bin` appended to `PATH`

The base machine still chooses `zsh` as the login shell in
`configuration.nix`; `dev.nix` only adds the richer workflow config.

### Containers And Virtual Machines

This module enables:

- `docker`
- `libvirtd`
- `virt-manager`
- `virt-viewer`
- SPICE USB redirection
- `swtpm` for TPM-aware VMs

That covers both local container workflows and desktop virtual machine
work.

### Local Host Aliases

Private host aliases are intentionally **not** stored in the main
development module anymore.

Instead, they can live in an optional encrypted secret:

`secrets/dev-private-hosts.age`

That means:

- the public repo does not contain plaintext client hostnames
- the normal `nixos-rebuild` command still works
- there is no second flake, wrapper script, or out-of-repo config
- if the encrypted file is absent, the config still evaluates cleanly

The decrypted plaintext should simply be host lines, for example:

```text
127.0.0.1 kafka
127.0.0.1 internal-api
127.0.0.1 client-service
```

Create or edit it with `agenix`:

```bash
agenix -e secrets/dev-private-hosts.age -i /home/bhoudebert/.ssh/id_ed25519
```

Then rebuild as usual:

```bash
sudo nixos-rebuild switch --flake .#home
```

When the encrypted secret exists, `dev.nix` decrypts it through `agenix`
and appends the non-comment lines into `/etc/hosts` during activation.
When it does not exist, nothing is appended and there is no first-run
error.

### Why Not Agenix

For this specific repo, `agenix` is the least bad fit because the
constraints are:

- keep the workflow on the normal flake rebuild command
- keep private hostnames out of the public repo
- avoid wrapper scripts and out-of-repo files

The tradeoff is that the secret content is plain host lines, not a Nix
module. That is intentional: it keeps the encrypted payload simple while
the Nix logic that consumes it stays in [home/dev.nix](/home/bhoudebert/nixos/home/dev.nix:83).

## Package Groups

The user package list in `dev.nix` is intentionally grouped by purpose.

### Editors And IDEs

- `kate` - simple GUI text editor
- `emacs` - full editor environment
- `vscode` - general IDE/editor
- `jetbrains-toolbox` - JetBrains launcher/installer

### Search And Navigation

- `eza` - richer `ls`
- `ripgrep` - fast content search
- `fd` - fast file finder

### Source Control And Downloads

- `git` - source control CLI
- `wget` - quick downloads and scripted fetches

### Nix Workflow Helpers

- `direnv` - auto-load project environments
- `nix-direnv` - direnv integration for Nix shells
- `manix` - search Nix options and docs
- `nix-index` - find which package provides a binary
- `nixfmt` - format Nix files

### Containers

- `docker`
- `docker-compose`

These stay in `dev.nix` because they are used as part of the local
development toolchain, not because the base OS needs them.

### Runtime / App Tooling

- `nodejs_25` - Node runtime for JavaScript and frontend tooling
- `dbeaver-bin` - database GUI
- `postman` - API testing GUI

### General Utilities

- `killall` - stop named processes quickly
- `dutree` - inspect disk usage
- `unzip` - extract archives
- `bubblewrap` - unprivileged sandboxing, useful for local tooling

## Why It Is Separate

This split makes the repo easier to reason about:

- `configuration.nix` answers: "What does this machine need to boot and
  behave like my desktop?"
- `dev.nix` answers: "What do I need to build, run, debug, and test
  software here?"

That separation is useful when:

- setting up a lighter machine later
- reviewing changes
- understanding why a package exists
- deciding whether something is personal desktop software or actual
  development tooling
