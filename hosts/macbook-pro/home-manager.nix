{ lib, pkgs, ... }:

let
  # This repository's dev leaf is a NixOS module whose user settings are
  # nested under home-manager.users. Select those settings for standalone HM.
  dev = import ../../modules/nixos/profiles/dev/home-manager.nix { };
  ai = import ../../modules/nixos/profiles/ai/shared.nix { inherit pkgs; };
in
{
  imports = [ dev.home-manager.users.bhoudebert ];

  # vscode, jetbrains-toolbox, postman, ... are unfree.
  nixpkgs.config.allowUnfree = true;

  home.sessionVariables.EDITOR = "vim";

  # Same package set as the NixOS dev profile, minus Linux-only entries.
  home.packages =
    import ../../modules/nixos/profiles/dev/packages.nix { inherit pkgs lib; }
    ++ ai.packages
    ++ (with pkgs; [
      # Docker engine for macOS (NixOS uses virtualisation.docker). It sets up
      # the `orbstack` docker context used by the Nix docker/compose CLIs.
      orbstack
      # Powerline glyphs for the agnoster zsh theme; select it in the terminal.
      nerd-fonts.jetbrains-mono
      # Terminal UI for Docker (talks to OrbStack's engine).
      lazydocker
      # Git-friendly API client (collections stored as plain files).
      bruno
      # CPU/GPU/RAM/network in the menu bar.
      stats
      # Friendlier HTTP client (`xh get httpbin.org/json`).
      xh
    ]);

  # Terminal UI for git.
  programs.lazygit.enable = true;

  # `cat` with syntax highlighting; used by delta for themes.
  programs.bat.enable = true;

  # Syntax-highlighted git diffs/pager.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true; # n/N to jump between files
      line-numbers = true;
    };
  };

  # Fuzzy finder: Ctrl+T (files), Alt+C (cd). Ctrl+R is left to atuin below.
  programs.fzf.enable = true;

  # Searchable shell history in SQLite, bound to Ctrl+R / Up arrow. Local
  # only; enable sync with `atuin register`/`atuin login` if ever wanted.
  programs.atuin = {
    enable = true;
    settings = {
      auto_sync = false;
      update_check = false;
    };
  };

  # Resource monitor.
  programs.btop.enable = true;

  # Node/npm come from Nix, so the default global prefix is the read-only store.
  # Same fix as NixOS (see npm-global-tools.md): install globals under ~/.local
  # (~/.local/bin is already on PATH via the shared zsh config).
  home.file.".npmrc".text = ''
    prefix=''${HOME}/.local
  '';

  # Ollama as a per-user launchd agent. Plain `ollama` uses Metal on the
  # Apple Silicon GPU; listens on 127.0.0.1:11434 (not exposed on the network).
  services.ollama = {
    enable = true;
    package = pkgs.ollama;
    environmentVariables = ai.ollamaEnvironment;
  };

  # The shared Linux alias still refers to the former name of eza.
  programs.zsh.shellAliases.ll = lib.mkForce "eza -al";

  # Enable flakes for the user (nix run, direnv/nix-direnv, home-manager).
  xdg.configFile."nix/nix.conf".text = ''
    experimental-features = nix-command flakes
  '';
}
