# npm Global CLI Tools On NixOS

On this machine, global npm CLI tools are installed under `~/.local`
instead of the Nix store.

This is necessary because the Node/npm package itself comes from Nix, and
the default npm global prefix can fall back to an immutable path under
`/nix/store/...`. When that happens, `npm install -g ...` breaks or emits
read-only filesystem warnings.

## Expected Layout

Global npm installs should land here:

- binaries in `~/.local/bin`
- packages in `~/.local/lib/node_modules`

For example, `codex` currently resolves as:

```text
~/.local/bin/codex -> ../lib/node_modules/@openai/codex/bin/codex.js
```

## Required Config

The key setting is in [`~/.npmrc`](/home/bhoudebert/.npmrc:1):

```text
prefix=/home/bhoudebert/.local
```

The shell side is already handled by [`~/.zshrc`](/home/bhoudebert/.zshrc:42):

```sh
export PATH="$HOME/.local/bin:$PATH"
```

That means no extra `bashrc` fix is needed on this machine.

## Quick Checks

Use these commands to confirm the setup:

```bash
npm config get prefix
npm prefix -g
which codex
codex --version
```

Expected prefix output:

```text
/home/bhoudebert/.local
```

## If It Breaks Again

Symptoms:

- `npm install -g ...` tries to write into `/nix/store/...`
- npm or a CLI warns about a read-only filesystem
- a global binary is missing from `PATH`

Checks:

1. Verify `npm config get prefix` still returns `/home/bhoudebert/.local`.
2. Verify `~/.zshrc` still exports `~/.local/bin` into `PATH`.
3. Open a new shell after changing shell config.

If needed, restore the first line of `~/.npmrc` to:

```text
prefix=/home/bhoudebert/.local
```
