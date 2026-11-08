{ lib, pkgs, ... }:

{
  # Shared dev profile user settings (git, mise, zsh) as a plain Home Manager module.
  imports = [ ../../modules/nixos/profiles/dev/user.nix ];

  home.sessionVariables.EDITOR = "vim";

  # The shared alias still refers to exa (kept unchanged so the NixOS hosts are
  # untouched); this host installs eza instead.
  programs.zsh.shellAliases.ll = lib.mkForce "eza -al";

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
}
