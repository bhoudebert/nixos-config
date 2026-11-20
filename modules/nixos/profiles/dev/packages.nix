# Dev profile user packages, shared by NixOS hosts (users.users.*.packages)
# and the standalone Home Manager MacBook setup (home.packages).
# Packages unavailable on the current platform are dropped automatically.
# `withGui = false` keeps only terminal tooling (used by the WSL setup, where
# the IDE runs on Windows and connects through VS Code Remote - WSL).
{
  pkgs,
  lib,
  withGui ? true,
  # On macOS OrbStack ships docker/compose/buildx matched to its engine (see
  # hosts/macbook-pro); on WSL the engine comes from the distro's apt packages.
  # In both cases the Nix CLIs would collide, so they are skipped.
  withDockerCli ? !pkgs.stdenv.hostPlatform.isDarwin,
}:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
builtins.filter (lib.meta.availableOn pkgs.stdenv.hostPlatform) (
  with pkgs;
  [
    # Editors.
    eza
    (
      if !withGui then
        emacs-nox
      else if isDarwin then
        emacs
      else
        emacs-pgtk
    )
    # Fast codebase navigation.
    ripgrep
    fd
    # Source control and basic transfer tools.
    git
    gh
    wget
    jq
    # Automatic shell environments for Nix-based projects.
    direnv
    nix-direnv
    # Misc CLI helpers.
    killall
    dutree
    # Nix docs, search, formatting, and LSPs.
    manix
    nix-index
    nixfmt
    nil
    nixd
    # Language/runtime/tooling baseline.
    nodejs
    python3
    pandoc
    go-grip
    github-copilot-cli
    maven
    # Utility packages mostly used during development.
    unzip
    bubblewrap
    nmap
    # language
    languagetool
    hunspell
    hunspellDicts.en_US-large
    hunspellDicts.fr-any
    # AI
    rtk
  ]
  ++ lib.optionals withGui [
    # Desktop development tools.
    kdePackages.kate
    # VS Code >= 1.144 moved its bundled rg to @vscode/ripgrep-universal; the
    # nixpkgs Darwin postPatch (only a chmod on the old path) now fails.
    # Drop it once nixpkgs catches up.
    (if isDarwin then vscode.overrideAttrs { postPatch = ""; } else vscode)
    # GUI tooling for databases, IDEs, and API testing.
    dbeaver-bin
    # nixpkgs' Darwin toolbox download URL is dead (404): ship IDEA directly.
    (if isDarwin then jetbrains.idea else jetbrains-toolbox)
    postman
    proton-vpn
  ]
  # Container tooling.
  ++ lib.optionals withDockerCli [
    docker
    docker-compose
  ]
)
