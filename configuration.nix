# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, awsvpnclient, home-manager, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (import "${home-manager}/nixos")
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # boot.kernelModules = [ "ecryptfs" ];

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable OpenGL
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement.enable = false;
    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Use Nvidia Prime to choose which GPU (iGPU or eGPU) to use.
    prime = {
      #sync.enable = true;
      allowExternalGpu = true;

      offload = {
        enable = true;
        enableOffloadCmd = true;
      };

      # Make sure to use the correct Bus ID values for your system!
      nvidiaBusId = "PCI:127:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # security.pam.enableEcryptfs = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  services.fprintd = {
    enable = true;
    #package = pkgs.fprintd-tod;
    #tod = {
    #  enable = true;
    #  driver = pkgs.libfprint-2-tod1-vfs0090;
    #};
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Define a user account. Don't forget to set a password with ‘passwd’.

  home-manager.users.bhoudebert = { pkgs, ... }: {
    home.stateVersion = "23.11";
    home.sessionVariables = {
      EDITOR = "vim";
    };
    programs.git = {
      enable = true;
      aliases = {
        st = "status";
        stp = "status --porcelain";
        ci = "commit";
        br = "branch";
        brd = "branch -d";
        co = "checkout";
        cob = "checkout -b";
        rz = "reset --hard HEAD";
        pullr = "pull --rebase";
        unstage = "reset HEAD";
        aa = "add -A .";
        cm = "commit -m";
        aacm = "!git add -A . && git commit -m";
        aacmpu = "!sh -c \"git add -A . && git commit -m '$1' && git pu\"";
        main = "!git checkout main && git pull origin";
        lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
        lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";
        lpush = "!git --no-pager log origin/$(git currentbranch)..HEAD --oneline";
        lpull = "!git --no-pager log HEAD..origin/$(git currentbranch) --oneline";
        whatsnew = "!git diff origin/$(git currentbranch)...HEAD";
        whatscoming = "!git diff HEAD...origin/$(git currentbranch)";
        currentbranch = "!git branch | grep \"^\\*\" | cut -d \" \" -f 2";
        po = "push origin";
        pu = "!git push origin `git branch --show-current`";
        plo = "pull origin";
        plom = "pull origin main";
        f = "!git ls-files | grep -i";
      };
      userEmail = "bhoudebert@gmail.com";
      userName = "bhoudebert";
      extraConfig = {
        core = { autocrlf = "input"; };
        init = { defaultBranch = "main"; };
      };
    };
    # For WSL only: https://learn.microsoft.com/en-us/windows/terminal/tutorials/custom-prompt-setup#set-cascadia-code-pl-as-fontface-in-settings
    # Install Cascadia Code PL https://github.com/microsoft/cascadia-code
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [
          "aws"
          "catimg"
          "colored-man-pages"
          "colorize"
          "command-not-found"
          "copybuffer"
          "copyfile"
          "copypath"
          "dircycle"
          "docker-compose"
          "docker"
          "emoji-clock"
          "encode64"
          "genpass"
          "gh"
          "git"
          "git-prompt"
          "history"
          "ipfs"
          "isodate"
          "jump"
          "ripgrep"
          "rsync"
          "rust"
          "sudo"
        ];
        theme = "agnoster";
      };
      shellAliases = { 
       ll = "exa -al";
      };
      initExtra = ''
        eval "$(direnv hook zsh)"
      '';
    };
  };

  programs.zsh.enable = true;

  users.users.bhoudebert = {
    isNormalUser = true;
    description = "bhoudebert";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    # home.stateVersion = "23.11";
    shell = pkgs.zsh;
    packages = with pkgs; [
      #  thunderbird
      eza
      brave
      discord
      emacs
      ripgrep
      fd
      vscode
      git
      wget
      spotify
      slack
      teams-for-linux
      openvpn
      steam
      awsvpnclient.packages.${system}.awsvpnclient
      direnv
      nix-direnv

      killall
      dutree

      manix
      nix-index

      gnome.gnome-tweaks

      docker
      docker-compose

      nixpkgs-fmt
    ];
  };

  # Install firefox.
  #programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    gnome.gnome-tweaks
    pciutils
    glxinfo
    lshw
    vim
    # ecryptfs
    lsof
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "unstable"; # Did you read the comment?

}
