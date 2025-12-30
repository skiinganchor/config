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
      flake-registry = "";
      auto-optimise-store = true;
      tarball-ttl = 0;
      trusted-users = [ "@wheel" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  programs.zsh.enable = true;

  system = {
    stateVersion = self.stateVersion;
  };
}
