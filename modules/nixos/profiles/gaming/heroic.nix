{ lib, pkgs, ... }:

{
  users.users.bhoudebert = {
    packages = with pkgs; [
      heroic
      protonup-qt
      mangohud
      gamemode
    ];
  };
}
