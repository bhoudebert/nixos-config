# MacBook Pro

Clone this repository on the Mac, then add this module to the existing
standalone Home Manager configuration (adjust the path to the checkout):

```nix
imports = [ /Users/YOUR_USER/path/to/nixos/hosts/macbook-pro/home-manager.nix ];
```

Keep the existing `home.username`, `home.homeDirectory`, and
`home.stateVersion` in that configuration. Apply changes using the same
command you currently use, typically `home-manager switch`. When using an
existing Home Manager flake, add this module to its `modules` list instead;
continue using its existing `home-manager switch --flake ...` command.

The module reuses the dev profile's Git, mise and Zsh settings and installs the
same package set as NixOS (`modules/nixos/profiles/dev/packages.nix`),
automatically skipping Linux-only entries. It does not import the NixOS dev
profile's system or Android modules. The shared Zsh setup runs `direnv` and invokes
`nix run` for its `claude` alias, so Nix and flakes need to be enabled on the
Mac.

The NixOS OneDrive module uses NixOS service options, and the `onedrive`
package is unavailable for Apple Silicon in the pinned nixpkgs. It is not
enabled here; choose a macOS-compatible sync client separately.

## Docker (OrbStack)

NixOS runs Docker through `virtualisation.docker`; on the Mac the engine is
OrbStack, installed from nixpkgs into `~/Applications/Home Manager Apps`.
OrbStack ships its own `docker`, `docker-compose`, `docker-buildx` and
`kubectl`, so the shared package list skips the Nix `docker`/`docker-compose`
on macOS to avoid collisions. Launch OrbStack once after the first switch so
it can finish its setup (it asks for admin rights for its helper). Updates come
through `nix-channel --update`, not OrbStack's own updater.

## npm global tools

Same fix as NixOS (`npm-global-tools.md`): `~/.npmrc` is managed here with
`prefix=${HOME}/.local`, so `npm install -g` writes to `~/.local` instead of
the read-only Nix store.

## CLI and GUI extras (Mac only for now)

| Tool | Use |
| --- | --- |
| `lazygit` / `lazydocker` | terminal UIs for git and Docker (OrbStack) |
| `delta` | git pager for diff/log/show/blame (line numbers, `n`/`N` between files) |
| `bat` | `cat` with syntax highlighting |
| `fzf` | Ctrl+T files, Alt+C cd |
| `atuin` | Ctrl+R / Up history search; local only (`auto_sync = false`) |
| `btop`, `xh` | resource monitor, HTTP client |
| Bruno, Stats | API client, menu-bar system monitor |

These are cross-platform; move them to `modules/nixos/profiles/dev/` to share
them with NixOS.

## Terminal font

The agnoster zsh theme needs Powerline glyphs. `nerd-fonts.jetbrains-mono` is
installed; select "JetBrainsMono Nerd Font" in the terminal profile.

## Ollama

Ollama runs as a per-user launchd agent (`services.ollama`) on
`127.0.0.1:11434`, using the same environment variables as NixOS
(`modules/nixos/profiles/ai/shared.nix`). It uses the Apple Silicon GPU through
Metal.

**No MLX support.** nixpkgs builds Ollama with `-DOLLAMA_MLX_BACKENDS=""`
because MLX needs Apple's proprietary `metal` shader compiler (shipped with
Xcode), which is not available in the Nix sandbox. Consequences:

- MLX-only tags fail with `this model requires MLX support, but the MLX
  runtime is not available`. This covers `*-mlx` tags and default tags that
  bundle a `draft` (speculative decoding) layer, such as `gemma4:26b`.
- GGUF tags work, for example `gemma4:26b-a4b-it-qat` or
  `gemma4:26b-a4b-it-q4_K_M`. Check a tag's layers on its ollama.com page if
  unsure.
- Output quality and token usage are the same; the cost is speed only. MLX is
  typically about 10–30% faster at generation on Apple Silicon, and the draft
  model can add more. Measure locally with `ollama run <model> --verbose`
  (`eval rate`).

If MLX speed matters, install the official Ollama.app from ollama.com instead,
and remove the `services.ollama` block from this module so the two servers do
not compete for port 11434.
