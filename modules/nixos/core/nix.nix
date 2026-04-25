{
  ...
}:

{
  # Enable the modern Nix CLI and flake support globally.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Required for proprietary software like NVIDIA, Slack, Spotify, etc.
  nixpkgs.config.allowUnfree = true;

  # NixOS state version for the system profile.
  system.stateVersion = "25.11";
}
