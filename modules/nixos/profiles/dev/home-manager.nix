{
  ...
}:

{
  home-manager.users.bhoudebert = {
    # Global git identity plus a large set of muscle-memory aliases.
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

    # Interactive shell experience for day-to-day development work.
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      oh-my-zsh = {
        enable = true;
        # Plugin set focused on git, docker, navigation, and misc CLI helpers.
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
        # Prompt theme with git branch/status visibility.
        theme = "agnoster";
      };
      shellAliases = {
        # Richer file listing.
        ll = "exa -al";
        # Shortcut for an external Claude runner.
        claude = "nix run github:ryoppippi/nix-claude-code";
      };
      initContent = ''
        # Auto-load per-project environments.
        eval "$(direnv hook zsh)"
        # Keep personal scripts available ahead of the system PATH tail.
        export PATH="$HOME/.local/bin:$PATH"
      '';
    };
  };
}
