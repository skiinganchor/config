{ self, ... }:

{
  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      persistent = true;
      options = "--delete-older-than 3d";
    };
    optimise = {
      automatic = true;
      dates = [ "daily" ];
    };
    settings = {
      auto-optimise-store = true;
      download-buffer-size = 268435456; # 256MB (default is 64MB)
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      flake-registry = "";
      tarball-ttl = 0;
      trusted-users = [ "@wheel" ];
    };
  };

  programs.zsh.enable = true;

  system = {
    stateVersion = self.stateVersion;
  };
}
