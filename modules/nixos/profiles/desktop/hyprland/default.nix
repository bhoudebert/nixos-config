{
  ...
}:

{
  # Optional Hyprland desktop branch layered on top of the Plasma baseline.
  # System bits install the compositor and portals; HM owns the dotfiles.
  imports = [
    ./home-manager.nix
    ./system.nix
  ];
}
