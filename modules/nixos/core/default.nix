{
  ...
}:

{
  # Core trunk shared by this host.
  # Each imported file owns one narrow concern so future changes stay local.
  imports = [
    ./audio.nix
    ./boot.nix
    ./dbus.nix
    ./desktop/plasma.nix
    ./home-manager.nix
    ./input.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./printing.nix
    ./programs.nix
    ./security.nix
    ./secrets.nix
    ./users.nix
  ];
}
