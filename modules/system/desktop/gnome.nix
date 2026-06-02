# modules/system/desktop/gnome.nix
#
# GNOME Desktop Environment — system-level configuration only.
#
# This module is intentionally limited to what is strictly GNOME-specific.
# Audio, printing, and Flatpak have been extracted into separate modules
# under modules/system/hardware/ so that future compositors (niri, Hyprland)
# can reuse those capabilities without importing this file.
#
# services.xserver.enable is kept even though we no longer use GDM, because
# autoRepeatDelay and autoRepeatInterval are still wired to the X11 input
# configuration layer in NixOS 26.05. This is a known upstream limitation;
# the options remain effective for Wayland sessions via the XKB subsystem.
#
# DISPLAY MANAGER NOTE:
# GDM is NOT enabled here. sukkub uses greetd (see modules/system/niri.nix)
# because GDM has a long-standing bug where it fails to pass environment
# variables (such as WLR_DRM_DEVICES) to non-GNOME Wayland sessions spawned
# on NVIDIA PRIME hybrid systems. greetd spawns the session directly as the
# user with a fully controlled environment, avoiding this entirely.
#
# GNOME can still be launched from greetd by selecting the gnome-wayland
# session entry, which is registered via services.desktopManager.gnome.
#
# gcr-ssh-agent (introduced in GNOME 44) supersedes the legacy SSH agent
# that was part of gnome-keyring. programs.ssh.startAgent must be false.
{ pkgs, ... }: {
  services.xserver = {
    enable = true;
    autoRepeatDelay    = 200;
    autoRepeatInterval = 35;
  };

  # GDM is intentionally disabled — greetd is used instead.
  # See modules/system/niri.nix for greetd configuration.
  services.displayManager.gdm.enable = false;

  services.desktopManager.gnome = {
    enable = true;
    extraGSettingsOverridePackages = [ pkgs.mutter ];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };

  services.gnome.gnome-keyring.enable = true;

  security.pam.services = {
    greetd.enableGnomeKeyring = true;
    login.enableGnomeKeyring  = true;
  };

  programs.dconf.enable = true;
  services.gnome.gcr-ssh-agent.enable = true;
  programs.ssh.startAgent = false;

  environment.gnome.excludePackages = with pkgs; [
    geary
    epiphany
    gnome-tour
    gnome-maps
    cheese
  ];

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  systemd.user.services.gsd-power.enable = false;
  systemd.user.services."org.gnome.SettingsDaemon.Power".enable = false;
}
