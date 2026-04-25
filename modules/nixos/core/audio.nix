{
  ...
}:

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
}
