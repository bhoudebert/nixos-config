{
  lib,
  pkgs,
  ...
}:

{
  # Main desktop user account and its always-available GUI applications.
  users.users.bhoudebert = {
    isNormalUser = true;
    description = "bhoudebert";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    # Default login shell for terminals and TTYs.
    shell = pkgs.zsh;
    packages =
      with pkgs;
      [
        # General browsing.
        librewolf
        brave
        chromium
        # Communication/media apps.
        discord
        spotify
        slack
      ];
  };
}
