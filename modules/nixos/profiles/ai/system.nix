{
  pkgs,
  ...
}:

let
  # Shared with the standalone Home Manager MacBook setup.
  ai = import ./shared.nix { inherit pkgs; };
in
{
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    package = pkgs.ollama-cuda; # use the RTX 5080
    environmentVariables = ai.ollamaEnvironment;
  };

  users.users.bhoudebert.packages = ai.packages;
}
