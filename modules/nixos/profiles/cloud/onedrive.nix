{
  pkgs,
  ...
}:
{
  users.users.bhoudebert = {
    packages = with pkgs; [
      onedrive
    ];
  };

  services.onedrive.enable = true;
}
