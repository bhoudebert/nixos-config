{ lib, pkgs, ... }:

let
  # This repository's dev leaf is a NixOS module whose user settings are
  # nested under home-manager.users. Select those settings for standalone HM.
  dev = import ../../modules/nixos/profiles/dev/home-manager.nix { };
  devUser = dev.home-manager.users.bhoudebert;
  ai = import ../../modules/nixos/profiles/ai/shared.nix { inherit pkgs; };

  # Minimal replacement for wslu's wslview (wslu was removed from nixpkgs):
  # open a URL or a Linux path with the default Windows application.
  wslview = pkgs.writeShellApplication {
    name = "wslview";
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "usage: wslview <url|path>" >&2
        exit 2
      fi
      target="$1"
      case "$target" in
        *://*) ;;
        *) target="$(/usr/bin/wslpath -w "$target")" ;;
      esac
      # explorer.exe returns 1 even on success.
      /mnt/c/Windows/explorer.exe "$target" || true
    '';
  };
in
{
  imports = [ devUser ];

  # Ubuntu on WSL2, single-user Nix install, standalone Home Manager.
  home.username = "ben";
  home.homeDirectory = "/home/ben";
  # Release this home was first activated with; do not bump on upgrades.
  home.stateVersion = "26.05";

  # Non-NixOS host: wire Nix paths, XDG data dirs and nix.sh into the session.
  targets.genericLinux.enable = true;

  # Let `home-manager switch --flake .#wsl` find its own CLI afterwards.
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
    # Open links (gh auth, OAuth flows, `xdg-open`) in the Windows browser.
    BROWSER = "wslview";
  };

  # Terminal-only dev set: the IDE is VS Code on Windows (Remote - WSL), and
  # the Docker engine comes from Ubuntu's docker-ce packages (systemd is on).
  home.packages =
    import ../../modules/nixos/profiles/dev/packages.nix {
      inherit pkgs lib;
      withGui = false;
      withDockerCli = false;
    }
    ++ ai.packages
    ++ (with pkgs; [
      # Windows interop: open files/URLs with the Windows default app.
      wslview
      # Terminal UI for Docker.
      lazydocker
      # Friendlier HTTP client (`xh get httpbin.org/json`).
      xh
      # Agent multiplexer: run and switch between coding agents in one TUI.
      herdr
    ]);

  # herdr opens new panes with $SHELL (bash, the WSL login shell); force zsh so
  # panes load the Home Manager ~/.zshrc. The file is read-only once managed.
  xdg.configFile."herdr/config.toml".source = (pkgs.formats.toml { }).generate "herdr-config.toml" {
    onboarding = false;
    terminal.default_shell = "${pkgs.zsh}/bin/zsh";
  };

  # Ghostty has no Windows build: this is the Linux app, shown through WSLg.
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
  };

  # Terminal UI for git.
  programs.lazygit.enable = true;

  # `cat` with syntax highlighting; used by delta for themes.
  programs.bat.enable = true;

  # Syntax-highlighted git diffs/pager.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
    };
  };

  # Fuzzy finder: Ctrl+T (files), Alt+C (cd). Ctrl+R is left to atuin below.
  programs.fzf = {
    enable = true;
    historyWidget.command = "";
  };

  # Searchable shell history in SQLite, bound to Ctrl+R / Up arrow. Local only.
  programs.atuin = {
    enable = true;
    settings = {
      auto_sync = false;
      update_check = false;
    };
  };

  # Resource monitor.
  programs.btop.enable = true;

  # direnv with cached `use flake` environments. The shared zsh config already
  # runs `direnv hook zsh`, so skip HM's own hook to avoid loading it twice.
  programs.direnv = {
    enable = true;
    enableZshIntegration = false;
    nix-direnv.enable = true;
  };

  # Node/npm come from Nix, so the default global prefix is the read-only store.
  # Same fix as NixOS (see npm-global-tools.md): install globals under ~/.local.
  home.file.".npmrc".text = ''
    prefix=''${HOME}/.local
  '';

  programs.zsh = {
    # Claude Code is installed natively under ~/.local/bin here; drop the
    # shared `nix run` alias so it does not shadow it. `ll` uses eza's name.
    shellAliases = lib.mkForce (
      builtins.removeAttrs devUser.programs.zsh.shellAliases [ "claude" ]
      // {
        ll = "eza -al";
        open = "wslview";
        # Second Claude Code identity (own login, settings and history).
        claude-atecna = "CLAUDE_CONFIG_DIR=$HOME/.claude-atecna claude";
      }
    );
  };

  # Enable flakes for the user (nix run, direnv/nix-direnv, home-manager).
  xdg.configFile."nix/nix.conf".text = ''
    experimental-features = nix-command flakes
  '';
}
