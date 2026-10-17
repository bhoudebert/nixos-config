{ pkgs, ... }:

let
  g9HdrReset = pkgs.writeShellApplication {
    name = "g9-hdr-reset";
    runtimeInputs = [
      pkgs.kdePackages.libkscreen
    ];
    text = ''
      set -eu

      output="''${G9_HDR_OUTPUT:-DP-4}"
      delay="''${G9_HDR_DELAY:-2}"

      kscreen-doctor "output.''${output}.hdr.disable"
      sleep "''${delay}"
      kscreen-doctor "output.''${output}.hdr.enable"
    '';
  };
in
{
  home-manager.users.bhoudebert = {
    home.packages = [
      g9HdrReset
      pkgs.ffmpeg
      pkgs.plasma-smart-video-wallpaper-reborn
    ];

    systemd.user.sessionVariables = {
      QT_MEDIA_BACKEND = "ffmpeg";
      QT_FFMPEG_DECODING_HW_DEVICE_TYPES = "cuda";
    };
  };
}
