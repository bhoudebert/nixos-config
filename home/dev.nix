{
  config,
  lib,
  pkgs,
  ...
}:

let
  devPrivateHostsSecretFile = ../secrets/dev-private-hosts.age;
  hasDevPrivateHostsSecret = builtins.pathExists devPrivateHostsSecretFile;
in
{
  # Desktop front-end for libvirt/QEMU virtual machines.
  programs.virt-manager.enable = true;

  # Local container and virtualization stack used for development, testing,
  # and disposable machines.
  virtualisation = {
    docker.enable = true;
    spiceUSBRedirection.enable = true;
    libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };
  };

  users.users.bhoudebert = {
    extraGroups = [
      "docker"
      "libvirtd"
      "kvm"
    ];

    packages = with pkgs; [
      # Editors and developer-facing shells.
      kdePackages.kate
      eza
      emacs-pgtk
      vscode

      # Fast local search and file discovery.
      ripgrep
      fd

      # Source control and basic download tooling.
      git
      wget

      # Automatic per-project environment loading for Nix shells.
      direnv
      nix-direnv

      # General CLI helpers used while debugging or cleaning local worktrees.
      killall
      dutree

      # Nix-specific discovery and formatting helpers.
      manix
      nix-index
      nixfmt

      # Local container tooling for development environments.
      docker
      docker-compose

      # Common runtime/tooling baseline for JavaScript-heavy projects.
      nodejs_25

      # GUI tools for backend/API/database work.
      dbeaver-bin
      jetbrains-toolbox
      postman

      # Small utility kept here because it is mostly used in development flows.
      unzip
      # Unprivileged sandboxing tool (e.g. useful for Codex).
      bubblewrap
    ];
  };

  # System-wide tools needed alongside the developer stack.
  environment.systemPackages = with pkgs; [
    # Keep Docker on PATH for system services and admin shells.
    docker
    # Viewer used to connect to local or remote virtual machine consoles.
    virt-viewer
  ];

  # Optional encrypted host aliases for client- or company-specific local
  # development endpoints. If the encrypted secret is absent, the public config
  # still evaluates cleanly and /etc/hosts stays unchanged.
  age.secrets.dev-private-hosts = lib.mkIf hasDevPrivateHostsSecret {
    file = devPrivateHostsSecretFile;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # Merge decrypted private host aliases into /etc/hosts only when the optional
  # encrypted secret exists and contains at least one non-comment line.
  system.activationScripts.devPrivateHosts = lib.mkIf hasDevPrivateHostsSecret
    (lib.stringAfter [ "agenixInstall" "etc" ] ''
      if ${pkgs.gnugrep}/bin/grep -Eqv '^[[:space:]]*($|#)' ${config.age.secrets.dev-private-hosts.path}; then
        ${pkgs.coreutils}/bin/install -m 0644 ${config.environment.etc.hosts.source} /etc/hosts
        ${pkgs.coreutils}/bin/printf '\n# Local private host aliases\n' >> /etc/hosts
        ${pkgs.coreutils}/bin/cat ${config.age.secrets.dev-private-hosts.path} >> /etc/hosts
      fi
    '');

  home-manager.users.bhoudebert = { ... }: {
    # Developer git defaults and shortcuts used across all repos on this machine.
    programs.git = {
      enable = true;
      settings = {
        alias = {
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
        user.email = "bhoudebert@gmail.com";
        user.name = "bhoudebert";
        core.autocrlf = "input";
        init.defaultBranch = "main";
      };
    };

    # Interactive shell config for development: git helpers, search plugins,
    # Docker helpers, and automatic direnv loading.
    #
    # For WSL only:
    # https://learn.microsoft.com/en-us/windows/terminal/tutorials/custom-prompt-setup#set-cascadia-code-pl-as-fontface-in-settings
    # Install Cascadia Code PL:
    # https://github.com/microsoft/cascadia-code
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
        # Fast directory listings with a richer file view.
        ll = "exa -al";
        # Shortcut to launch Claude via its flake entry point.
        claude = "nix run github:ryoppippi/nix-claude-code";
      };
      initContent = ''
        # Automatically load .envrc files in project directories.
        eval "$(direnv hook zsh)"
        # Keep user-local scripts available without installing them globally.
        export PATH="$HOME/.local/bin:$PATH"
      '';
    };
  };
}
