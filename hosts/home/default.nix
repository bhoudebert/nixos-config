{
  ...
}:

{
  # Host root for the main workstation.
  # This file is intentionally small: it wires hardware, core defaults, and
  # feature profiles together without carrying implementation details itself.
  imports = [
    # Hardware-specific filesystem, initrd, and platform declarations.
    ./hardware-configuration.nix
    ./system.nix
    # Shared machine baseline: boot, locale, users, desktop defaults, etc.
    ../../modules/nixos/core
    # Feature branches enabled on this host.
    ../../modules/nixos/profiles/dev
    ../../modules/nixos/profiles/gaming
    ../../modules/nixos/profiles/desktop/hyprland
    ../../modules/nixos/profiles/monitoring
  ];
}
