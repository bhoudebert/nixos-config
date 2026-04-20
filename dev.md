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

Instead, the repo now ships a ready-to-use local override file:
[home/dev-private.nix](/home/bhoudebert/nixos/home/dev-private.nix:1)

It is imported by default from `configuration.nix`, so you do not need a
second flake or any extra wiring.

The file starts as a safe no-op:

```nix
{ ... }:

{
  networking.extraHosts = ''
    # 127.0.0.1 kafka
    # 127.0.0.1 internal-api
    # 127.0.0.1 client-service
  '';
}
```

To use it, just edit that file locally and uncomment or replace the
example lines:

```nix
networking.extraHosts = ''
  127.0.0.1 kafka
  127.0.0.1 internal-api
  127.0.0.1 client-service
'';
```

Then rebuild normally from this repo:

```bash
sudo nixos-rebuild switch --flake .#home
```

### Keeping It Out Of Git

Because `home/dev-private.nix` is tracked, local edits would normally
show up in `git status`.

If you want to keep using the file locally without seeing those changes
all the time, mark it as local-only in your Git index:

```bash
git update-index --skip-worktree home/dev-private.nix
```

This flag is **local Git state**, not repository data. That means:

- it fixes the problem on your current clone
- each new clone must run the command once for itself
- Git cannot store this behavior in the repo for everyone automatically

If you ever want Git to track changes to that file again:

```bash
git update-index --no-skip-worktree home/dev-private.nix
```

This gives you the simple "one local file" workflow without needing a
private overlay repository.

### Why Not Agenix

`agenix` is the right tool for secrets like passwords, tokens, and
service keys. It is **not** the right tool for `/etc/hosts`.

Reasons:

- `/etc/hosts` is assembled as part of the system configuration
- the host mappings are not true secrets once deployed
- trying to decrypt them with `agenix` just to copy them into
  `/etc/hosts` adds complexity without meaningful protection

So the best split is:

- `agenix` for actual secrets
- a private wrapper module/repo for confidential host aliases

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
