{
  ...
}:

{
  # Development profile:
  # system services/packages for containers and VMs plus user shell/git config.
  imports = [
    ./home-manager.nix
    ./system.nix
  ];
}
