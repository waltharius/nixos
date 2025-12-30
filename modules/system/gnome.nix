# GNOME Desktop Environment configuration
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable X11 windowing system
  services.xserver = {
    enable = true;

    # Keyboard repeat rate
    autoRepeatDelay = 200;
    autoRepeatInterval = 35;
  };

  # Enable GDM display manager
  services.displayManager.gdm.enable = true;

  # Enable GNOME Desktop
  services.desktopManager.gnome = {
    enable = true;

    # Enable fractional scaling
    extraGSettingsOverridePackages = [pkgs.mutter];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };

  # Enable GNOME Keyring with SSH agent support
  services.gnome.gnome-keyring.enable = true;

  # Enable PAM integration to auto-unlock keyring with login password
  security.pam.services.gdm.enableGnomeKeyring = true;

  # Ensure system-wide SSH agent doesn't conflict
  programs.ssh.startAgent = false;

  # Remove unwanted GNOME packages
  environment.gnome.excludePackages = with pkgs; [
    geary
    epiphany
    gnome-tour
    gnome-maps
    cheese
  ];

  # Enable Flatpak for additional applications
  services.flatpak.enable = true;

  # XDG portal for Flatpak integration
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };

  # Enable CUPS for printing
  services.printing.enable = true;

  # Enable PipeWire for audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
