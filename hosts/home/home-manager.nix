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
      pkgs.herdr
      pkgs.warp-terminal
      pkgs.whatsapp-electron
      pkgs.plasma-smart-video-wallpaper-reborn
    ];

    programs.ghostty = {
      enable = true;
      package = pkgs.symlinkJoin {
        name = "ghostty-with-dead-keys";
        paths = [ pkgs.ghostty ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/ghostty" \
            --set GTK_IM_MODULE simple \
            --add-flags "--gtk-single-instance=false"
          cp --remove-destination ${pkgs.ghostty}/share/applications/com.mitchellh.ghostty.desktop \
            "$out/share/applications/com.mitchellh.ghostty.desktop"
          substituteInPlace "$out/share/applications/com.mitchellh.ghostty.desktop" \
            --replace-fail 'Exec=ghostty --gtk-single-instance=true' "Exec=$out/bin/ghostty" \
            --replace-fail 'DBusActivatable=true' 'DBusActivatable=false'
        '';
      };
    };

    systemd.user.sessionVariables = {
      QT_MEDIA_BACKEND = "ffmpeg";
      QT_FFMPEG_DECODING_HW_DEVICE_TYPES = "cuda";
    };
  };
}
