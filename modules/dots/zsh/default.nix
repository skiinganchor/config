{ ... }:
{
  programs = {
    direnv = {
      enable = true;
      enableZshIntegration = true;
    };

    zsh = {
      enable = true;
      enableCompletion = false;
      zplug = {
        enable = true;
        plugins = [
          { name = "zsh-users/zsh-autosuggestions"; }
          { name = "zsh-users/zsh-syntax-highlighting"; }
          { name = "zsh-users/zsh-completions"; }
          { name = "zsh-users/zsh-history-substring-search"; }
          { name = "unixorn/warhol.plugin.zsh"; }
        ];
      };
      initContent = ''
        # Cycle back in the suggestions menu
        bindkey '^[[Z' reverse-menu-complete # Shift+Tab

        # Toggle zsh-autosuggestions
        bindkey '^B' autosuggest-toggle # Control+B

        # Make Ctrl+W remove one path segment instead of the whole path
        WORDCHARS=''${WORDCHARS/\/}

        # Highlight the selected suggestion
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
        zstyle ':completion:*' menu yes=long select

        export EDITOR=nvim || export EDITOR=vim
        export LANG=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
        export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

        # Colorizing plugin
        source $ZPLUG_HOME/repos/unixorn/warhol.plugin.zsh/warhol.plugin.zsh
        # History-substring search options
        bindkey '^[[A' history-substring-search-up # Up
        bindkey '^[[B' history-substring-search-down # Down

        if command -v motd &> /dev/null
        then
          motd
        fi
        # Use emacs keymap
        bindkey -e
        # Map the specific sequences you found via cat -v
        bindkey '^[[1~' beginning-of-line       # Home
        bindkey '^[[4~' end-of-line             # End
        bindkey '^[[3~' delete-char             # Delete
        bindkey '^[[5~' beginning-of-history    # PageUp
        bindkey '^[[6~' end-of-history          # PageDown
      '';
      syntaxHighlighting.enable = true;
      shellAliases = {
        clip = "wl-copy";
        cplocal = "viewlocal|clip";
        editflake = "sudo nvim /etc/nixos/flake.nix";
        editlocal = "sudo nvim /etc/nixos/local.nix";
        viewflake = "cat /etc/nixos/flake.nix";
        viewlocal = "cat /etc/nixos/local.nix";
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
        # temporary fix for yh - see docs for YT-DLP
        # based on https://github.com/TheFrenchGhosty/TheFrenchGhostys-Ultimate-YouTube-DL-Scripts-Collection/blob/master/scripts/Archivist%20Scripts/Archivist%20Scripts/Unique/Unique.sh
        ytd = "yt-dlp --write-info-json --all-subs --continue --format=bestvideo+bestaudio";
      };
    };
  };
}
