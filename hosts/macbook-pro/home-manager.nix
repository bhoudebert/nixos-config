{ lib, pkgs, ... }:

let
  # This repository's dev leaf is a NixOS module whose user settings are
  # nested under home-manager.users. Select those settings for standalone HM.
  dev = import ../../modules/nixos/profiles/dev/home-manager.nix { };
in
{
  imports = [ dev.home-manager.users.bhoudebert ];

  home.sessionVariables.EDITOR = "vim";

  home.packages = with pkgs; [
    direnv
    eza
    fd
    gh
    jq
    maven
    nil
    nix-direnv
    nixd
    nixfmt
    nodejs
    python3
    ripgrep
    wget
  ];

  # The shared Linux alias still refers to the former name of eza.
  programs.zsh.shellAliases.ll = lib.mkForce "eza -al";
}
