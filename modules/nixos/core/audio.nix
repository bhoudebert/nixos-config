{
  pkgs,
  ...
}:

let
  fixAudio = pkgs.writeShellScriptBin "fix-audio" ''
    set -u

    spdif_id="$(${pkgs.wireplumber}/bin/wpctl status | ${pkgs.gawk}/bin/awk '
      /USB Audio S\/PDIF Output/ {
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^[0-9]+\.$/) {
            sub(/\.$/, "", $i)
            print $i
            exit
          }
        }
      }
    ')"

    if [ -n "$spdif_id" ]; then
      ${pkgs.wireplumber}/bin/wpctl set-default "$spdif_id" || true
      ${pkgs.wireplumber}/bin/wpctl set-mute "$spdif_id" 0 || true
      ${pkgs.wireplumber}/bin/wpctl set-volume "$spdif_id" 1.0 || true
    else
      echo "USB Audio S/PDIF Output sink not found." >&2
    fi

    ${pkgs.alsa-utils}/bin/amixer -q -c Audio cset numid=22 on || true
    ${pkgs.systemd}/bin/systemctl --user restart pipewire-pulse

    echo "Reasserted USB S/PDIF output and restarted pipewire-pulse."
  '';
in
{
  # PipeWire is the machine audio server for desktop, games, and screen share.
  # PulseAudio is disabled because PipeWire provides the Pulse-compatible layer.
  services.pulseaudio.enable = false;
  # Real-time scheduling support helps low-latency audio stay responsive.
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    # ALSA provides native Linux audio device support.
    alsa.enable = true;
    # 32-bit audio support is needed for older games and compatibility layers.
    alsa.support32Bit = true;
    # Pulse protocol compatibility for most desktop apps.
    pulse.enable = true;
  };

  # Local recovery command for the ASRock onboard USB audio S/PDIF path when
  # browser playback leaves PipeWire/Pulse in a silent state.
  environment.systemPackages = [
    fixAudio
    pkgs.alsa-utils
  ];
}
