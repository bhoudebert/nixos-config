{
  home-manager,
  ...
}:

{
  # Attach the Home Manager NixOS module so user config can live in this repo
  # and be activated alongside the system generation.
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.bhoudebert = {
    # HM state version tracks the release whose defaults the user profile expects.
    home.stateVersion = "25.11";
    home.sessionVariables = {
      # Default editor used by shells, git, and many CLI tools.
      EDITOR = "vim";
    };
  };
}
