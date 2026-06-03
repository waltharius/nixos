# modules/system/desktop/gnome.nix
#
# GNOME Desktop Environment with GDM — system-level configuration only.
#
# This module is self-contained: it owns GNOME and GDM and knows nothing
# about greetd, niri, or any other compositor. Import it on any host
# that should boot into GNOME via GDM.
#
# Audio, printing, and Flatpak live in modules/system/hardware/ so that
# future compositors (niri, Hyprland) can reuse them without importing
# this file.
#
# services.xserver.enable is kept because autoRepeatDelay and
# autoRepeatInterval are wired to the X11 input layer in NixOS 26.05
# and remain effective for Wayland sessions via the XKB subsystem.
#
# gcr-ssh-agent (GNOME 44+) supersedes the legacy SSH agent in
# gnome-keyring. programs.ssh.startAgent must be false.
{ pkgs, ... }: {
  services.xserver = {
    enable             = true;
    autoRepeatDelay    = 200;
    autoRepeatInterval = 35;
  };

  services.displayManager.gdm.enable = true;

  services.desktopManager.gnome = {
    enable = true;
    extraGSettingsOverridePackages = [ pkgs.mutter ];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  programs.dconf.enable               = true;
  services.gnome.gcr-ssh-agent.enable = true;
  programs.ssh.startAgent             = false;

  environment.gnome.excludePackages = with pkgs; [
    geary
    epiphany
    gnome-tour
    gnome-maps
    cheese
  ];

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  systemd.user.services.gsd-power.enable                            = false;
  systemd.user.services."org.gnome.SettingsDaemon.Power".enable     = false;
}
