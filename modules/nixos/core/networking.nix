{
  ...
}:

{
  # Local hostname exposed to the network and shell prompts.
  networking.hostName = "nixos";
  # NetworkManager handles Wi-Fi/Ethernet/VPNs for the desktop machine.
  networking.networkmanager.enable = true;
}
