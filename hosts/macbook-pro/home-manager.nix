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
    ]);

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
