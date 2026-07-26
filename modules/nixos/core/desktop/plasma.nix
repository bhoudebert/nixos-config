{
  pkgs,
  ...
}:

{
  # X11 remains enabled because Plasma still interoperates with tools that
  # expect Xorg, even though the machine also uses Wayland sessions.
  services.xserver.enable = true;

  # Plasma desktop stack with SDDM as the login manager.
  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.desktopManager.plasma6.enable = true;

  # Desktop portal plumbing for file pickers, screen sharing, and sandboxed apps.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.common.default = "kde";
  };

  # SMB client integration for Dolphin/KIO plus CLI tools for diagnostics and
  # optional CIFS mounts.
  environment.systemPackages = with pkgs; [
    cifs-utils
    samba
    kdePackages.kio-extras
    kdePackages.kio-fuse
  ];

  environment.etc."samba/smb.conf".text = ''
    [global]
      client min protocol = SMB2
      client max protocol = SMB3
  '';

  # Declarative Flatpak setup for a small set of GUI apps kept outside nixpkgs.
  services.flatpak = {
    enable = true;
    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      # Xbox Cloud / remote-play client.
      "io.github.unknownskl.greenlight"
    ];
    update.onActivation = true;
  };
}
