{ pkgs, ... }:

let
  # Packages that make the Hyprland session usable out of the box.
  hyprlandPackages = with pkgs; [
    hyprland
    hyprpaper
    hyprlock
    hypridle
    waybar
    wofi
    mako
    kitty
    grim
    slurp
    wl-clipboard
    brightnessctl
    playerctl
    networkmanagerapplet
    pavucontrol
  ];
in
{
  # Wayland compositor and Xwayland compatibility for legacy apps.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Portal stack for screenshots, file pickers, and screen sharing.
  xdg.portal = {
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
    config = {
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
      };
    };
  };

  # PolicyKit is needed for desktop privilege prompts in the session.
  security.polkit.enable = true;

  # Session applications and utilities installed system-wide.
  environment.systemPackages = hyprlandPackages;
}
