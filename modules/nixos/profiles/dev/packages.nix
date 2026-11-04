# Dev profile user packages, shared by NixOS hosts (users.users.*.packages)
# and the standalone Home Manager MacBook setup (home.packages).
# Packages unavailable on the current platform are dropped automatically.
{ pkgs, lib }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
builtins.filter (lib.meta.availableOn pkgs.stdenv.hostPlatform) (
  with pkgs;
  [
    # Editors and desktop development tools.
    kdePackages.kate
    eza
    (if isDarwin then emacs else emacs-pgtk)
    # VS Code >= 1.144 moved its bundled rg to @vscode/ripgrep-universal; the
    # nixpkgs Darwin postPatch (only a chmod on the old path) now fails.
    # Drop it once nixpkgs catches up.
    (if isDarwin then vscode.overrideAttrs { postPatch = ""; } else vscode)
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
    # Container tooling.
    docker
    docker-compose
    # Language/runtime/tooling baseline.
    nodejs
    python3
    pandoc
    go-grip
    github-copilot-cli
    maven
    # GUI tooling for databases, IDEs, and API testing.
    dbeaver-bin
    # nixpkgs' Darwin toolbox download URL is dead (404): ship IDEA directly.
    (if isDarwin then jetbrains.idea else jetbrains-toolbox)
    postman
    # Utility packages mostly used during development.
    unzip
    bubblewrap
    nmap
    proton-vpn
    # language
    languagetool
    hunspell
    hunspellDicts.en_US-large
    hunspellDicts.fr-any
    # AI
    rtk
  ]
)
