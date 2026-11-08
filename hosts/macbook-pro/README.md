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

The flake also exposes `homeConfigurations.macbook-pro` (aarch64-darwin,
user `bhoudebert`, home `/Users/bhoudebert`) so the module can be built with
`nix build .#homeConfigurations.macbook-pro.activationPackage` on the Mac, or
switched with `home-manager switch --flake .#macbook-pro`. Adjust the username
and home directory in `flake.nix` if they differ. It has not been evaluated
from the Linux machine this was written on; run the build on the Mac first.

Note that the module hardwires the dev profile's Git identity
(`bhoudebert <bhoudebert@gmail.com>`), which overrides any `programs.git`
identity in the existing configuration. If Home Manager reports that a file
such as `~/.zshrc` or `~/.gitconfig` already exists, move it aside before
switching.

The module reuses the dev profile's Git, mise and Zsh settings and installs a
selection of development tools. It does not import the NixOS dev profile's
system or Android modules. The shared Zsh setup runs `direnv` and invokes
`nix run` for its `claude` alias, so Nix and flakes need to be enabled on the
Mac.

The NixOS OneDrive module uses NixOS service options, and the `onedrive`
package is unavailable for Apple Silicon in the pinned nixpkgs. It is not
enabled here; choose a macOS-compatible sync client separately.
