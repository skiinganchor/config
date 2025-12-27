{ pkgs, ... }:

{
  # Configure graphical interfaces
  services = {
    gnome = {
      core-apps.enable = true;
      gnome-keyring.enable = true;
    };
    desktopManager.gnome.enable = true;
    displayManager.gdm = {
      enable = true;
      autoSuspend = false;
      wayland = true;
    };
    displayManager = {
      defaultSession = "gnome";
    };
  };

  networking.networkmanager.enable = true;

  hardware = {
    graphics.enable = true;
  };

  environment.gnome.excludePackages = with pkgs; [
    epiphany    # web browser
  ];

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
  };

  fonts = {
    packages = with pkgs; [
      nerd-fonts.noto
    ];
    enableDefaultPackages = true;
  };
}
