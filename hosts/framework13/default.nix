{
  ...
}:

{
  # Host root for the Framework 13 laptop.
  # It shares the baseline machine config while selecting a smaller profile set.
  imports = [
    ./hardware-configuration.nix
    ./system.nix
    ../../modules/nixos/core
    ../../modules/nixos/profiles/dev
    ../../modules/nixos/profiles/monitoring
  ];
}
