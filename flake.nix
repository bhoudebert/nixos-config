{
  # Flake entrypoint for this machine repo.
  # It pins upstream inputs and exposes one NixOS host named `home`.
  description = "Home machine NixOS";

  inputs = {
    # Track a recent NixOS branch for system packages and modules.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
    # agenix provides age-encrypted secrets stored safely in git.
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, home-manager, nix-flatpak, agenix, ... }@attrs: {
    nixosConfigurations = {
      # Main desktop/workstation configuration.
      home =
        let
          # Single target architecture for this machine.
          system = "x86_64-linux";
        in
        nixpkgs.lib.nixosSystem {
          inherit system;  # Change this if the target machine uses another architecture.
          # Make flake inputs available to downstream modules through specialArgs.
          specialArgs = attrs;
          # Compose the system from the base config plus extra modules.
          modules = [
            ./hosts/home/default.nix  # Main machine configuration.
            # Declarative Flatpak support.
            nix-flatpak.nixosModules.nix-flatpak
            # Age-encrypted secret management.
            agenix.nixosModules.default
            {
              # Install the agenix CLI so secrets can be edited and rekeyed locally.
              environment.systemPackages = [ agenix.packages.${system}.default ];
            }
          ];
        };
    };
  };
}
