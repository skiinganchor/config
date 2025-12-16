{ config, ... }:

{
  programs.git = {
    enable = true;
    config = {
      credential.helper = "cache --timeout=36000";
      core = {
        editor = "vi";
        autocrlf = "input";
      };
      color.ui = "always";
      init.defaultBranch = config.homelab.git.defaultBranch;
      alias = {
        c = "commit";
        ca = "commit -a";
        cm = "commit -m";
        cam = "commit -am";
        d = "diff";
        dc = "diff --cached";
        graph = "log --graph --all --oneline";
        l = ''log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'';
        acommit = "commit --amend --no-edit --all";
        fpush = "push --force-with-lease";
      };
      push.autoSetupRemote = true;
      pull.rebase = true;
    };
  };
}
