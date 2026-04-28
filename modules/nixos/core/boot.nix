{ ... }:

{
  # EFI boot via systemd-boot.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Generic graphics userspace support shared by desktop hosts.
  hardware.graphics = {
    enable = true;
  };
}
