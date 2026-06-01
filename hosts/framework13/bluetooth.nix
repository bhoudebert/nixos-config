{ ... }:

{
  # Framework 13 ships an Intel AX210 (Wi-Fi 6E + Bluetooth 5.x) module. Enabling
  # the controller plus the bluetooth service is all that is needed; the firmware
  # is already provided by hardware.enableRedistributableFirmware in the core
  # hardware profile.
  #
  # The Plasma baseline (modules/nixos/core/desktop/plasma.nix) brings the
  # BlueDevil applet, so pairing is done from System Settings -> Bluetooth or the
  # system tray; no extra GUI is wired up here.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      # Expose battery levels for headsets/controllers and enable fast,
      # reliable reconnection of audio devices.
      Experimental = true;
    };
  };
}
