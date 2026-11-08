{
  ...
}:

{
  # NixOS wrapper: the actual user settings live in ./user.nix so that
  # standalone Home Manager hosts (hosts/macbook-pro) can import them directly.
  home-manager.users.bhoudebert = ./user.nix;
}
