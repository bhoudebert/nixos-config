{ lib, pkgs, ... }:

let
  # This repository's dev leaf is a NixOS module whose user settings are
  # nested under home-manager.users. Select those settings for standalone HM.
  dev = import ../../modules/nixos/profiles/dev/home-manager.nix { };
in
{
  imports = [ dev.home-manager.users.bhoudebert ];

  # vscode, jetbrains-toolbox, postman, ... are unfree.
  nixpkgs.config.allowUnfree = true;

  home.sessionVariables.EDITOR = "vim";

  # Same package set as the NixOS dev profile, minus Linux-only entries.
  home.packages = import ../../modules/nixos/profiles/dev/packages.nix { inherit pkgs lib; };

  # The shared Linux alias still refers to the former name of eza.
  programs.zsh.shellAliases.ll = lib.mkForce "eza -al";

  # Enable flakes for the user (nix run, direnv/nix-direnv, home-manager).
  xdg.configFile."nix/nix.conf".text = ''
    experimental-features = nix-command flakes
  '';
}
