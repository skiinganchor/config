{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      clip = "wl-copy";
      cplocal = "viewlocal|clip";
      df = "df -hT";
      editflake = "sudo nvim /etc/nixos/flake.nix";
      editlocal = "sudo nvim /etc/nixos/local.nix";
      viewflake = "cat /etc/nixos/flake.nix";
      viewlocal = "cat /etc/nixos/local.nix";
      mkdir = "mkdir -p";
      ngc = "nix store gc";
      # git aliases inspired on https://kapeli.com/cheat_sheets/Oh-My-Zsh_Git.docset/Contents/Resources/Documents/index
      ga = "git add";
      gac = "git commit --amend --no-edit --all";
      gap = "git commit --amend --no-edit --all && git push --force-with-lease";
      gc = "git commit -m";
      gcf = "git config --list";
      gco = "git checkout";
      gf = "git fetch";
      gfa = "git fetch --all --prune";
      gfo = "git fetch origin";
      gfp = "git push --force-with-lease";
      glg = ''git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'';
      gl = "git pull";
      gp = "git push";
      gr = "git reset";
      grb = "git rebase";
      grba = "git rebase --abort";
      grbc = "git rebase --continue";
      gs = "git status";
      gsta = "git stash";
      gstaa = "git stash apply";
      gstl = "git stash list";
      ipp = "curl ipinfo.io/ip";
      la = "ls --color -lha";
      ls = "ls --color=auto";
      nfu = "nix flake update";
      nixup = "sudo nix flake update --flake /etc/nixos && sudo nixos-rebuild switch";
      yh = "yt-dlp --continue --no-check-certificate --format=bestvideo+bestaudio --exec='ffmpeg -i {} -c:a copy -c:v copy {}.mkv && rm {}'";
      # usage yd <video-id> or ya <video-id> (just audio)
      yd = "yt-dlp --continue --no-check-certificate --format=bestvideo+bestaudio --exec='ffmpeg -i {} -c:v prores_ks -profile:v 1 -vf fps=25/1 -pix_fmt yuv422p -c:a pcm_s16le {}.mov && rm {}'";
      ya = "yt-dlp --continue --no-check-certificate --format=bestaudio -x --audio-format wav";
    };
  };
}
