{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Optional encrypted hosts fragment for private client/company endpoints.
  devPrivateHostsSecretFile = ../../../../secrets/dev-private-hosts.age;
  hasDevPrivateHostsSecret = builtins.pathExists devPrivateHostsSecretFile;
in
{
  # GUI for libvirt/QEMU virtual machines.
  programs.virt-manager.enable = true;

  # Local virtualization/container stack used for development and testing.
  virtualisation = {
    docker.enable = true;
    # Lets SPICE guests access redirected USB devices.
    spiceUSBRedirection.enable = true;
    libvirtd = {
      enable = true;
      # Virtual TPM support for modern guest OS requirements.
      qemu.swtpm.enable = true;
    };
  };

  # Local HTTP proxy that forwards traffic into an SSH SOCKS endpoint.
  services.privoxy = {
    enable = true;
    settings = {
      listen-address = "127.0.0.1:8118";
      forward-socks5 = "/ 127.0.0.1:1085 .";
    };
  };

  users.users.bhoudebert = {
    # Extra privileges needed for Docker and KVM/libvirt workflows.
    extraGroups = [
      "docker"
      "libvirtd"
      "kvm"
    ];

    # Shared with the standalone Home Manager MacBook setup.
    packages = import ./packages.nix { inherit pkgs lib; };
  };

  # System-level tools needed outside the user profile too.
  environment.systemPackages = with pkgs; [
    docker
    virt-viewer
  ];

  # Only expose this secret when the encrypted file exists in the repo.
  age.secrets.dev-private-hosts = lib.mkIf hasDevPrivateHostsSecret {
    file = devPrivateHostsSecretFile;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # Merge optional private host aliases into /etc/hosts during activation.
  system.activationScripts.devPrivateHosts = lib.mkIf hasDevPrivateHostsSecret (
    lib.stringAfter [ "agenixInstall" "etc" ] ''
      if ${pkgs.gnugrep}/bin/grep -Eqv '^[[:space:]]*($|#)' ${config.age.secrets.dev-private-hosts.path}; then
        ${pkgs.coreutils}/bin/install -m 0644 ${config.environment.etc.hosts.source} /etc/hosts
        ${pkgs.coreutils}/bin/printf '\n# Local private host aliases\n' >> /etc/hosts
        ${pkgs.coreutils}/bin/cat ${config.age.secrets.dev-private-hosts.path} >> /etc/hosts
      fi
    ''
  );
}
