{
  pkgs,
  ...
}:

{
  # CUPS enables local and network printer support.
  services.printing = {
    enable = true;
    browsing = true;
    listenAddresses = [ "*:631" ];
    allowFrom = [ "all" ];

    drivers = with pkgs; [
      gutenprint
      hplip
      brlaser
      samsung-unified-linux-driver
    ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  networking.firewall.allowedTCPPorts = [ 631 ];
  networking.firewall.allowedUDPPorts = [ 631 5353 ];
}
