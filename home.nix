{ config, pkgs , ...}:

{
  # programs.home-manager.enable = "true";
 
  home.username = "bhoudebert";
  home.homeDirectory = "/home/bhoudebert";

  home.packages = with pkgs; [
    emacs
    vim
    vscode
    spotify
    brave
    teams
    slack
    git
  ];

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

  # home.stateVersion = "22.05";
}