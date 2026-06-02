# modules/system/desktop/gnome.nix
#
# GNOME Desktop Environment — system-level configuration only.
#
# This module is intentionally limited to what is strictly GNOME-specific.
# Audio, printing, and Flatpak have been extracted into separate modules
# under modules/system/hardware/ so that future compositors (niri, Hyprland)
# can reuse those capabilities without importing this file.
#
# services.xserver.enable is kept even though GDM runs on Wayland, because
# autoRepeatDelay and autoRepeatInterval are still wired to the X11 input
# configuration layer in NixOS 26.05. This is a known upstream limitation;
# the options remain effective for Wayland sessions via the XKB subsystem.
#
# services.displayManager.gdm.wayland = true is set explicitly for clarity
# even though it is the default in NixOS 26.05. Explicit values prevent
# accidental regressions if the upstream default ever changes.
#
# gcr-ssh-agent (introduced in GNOME 44) supersedes the legacy SSH agent
# that was part of gnome-keyring. It correctly handles ed25519 and other
# modern key types. programs.ssh.startAgent must be false to prevent the
# system-wide OpenSSH agent from competing with gcr-ssh-agent for the
# SSH_AUTH_SOCK socket.
#
# gsd-power (GNOME Settings Daemon power plugin) is disabled on laptop
# hosts because TLP manages power profiles and the two daemons conflict
# over CPU governor and battery charge thresholds.
#
# The GNOME-specific XDG portal backend is declared here and is
# automatically merged with the GTK fallback from
# modules/system/hardware/flatpak.nix by the NixOS list-merge semantics.
{ pkgs, ... }: {
  services.xserver = {
    enable = true;
    autoRepeatDelay = 200;
    autoRepeatInterval = 35;
  };

  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  services.desktopManager.gnome = {
    enable = true;
    # Enable fractional scaling via the experimental mutter feature flag.
    # Required for HiDPI displays that do not align to integer scale factors.
    extraGSettingsOverridePackages = [ pkgs.mutter ];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };

  services.gnome.gnome-keyring.enable = true;

  # Auto-unlock the keyring when the user logs in through GDM or the
  # console. Without PAM integration the keyring stays locked until the
  # user manually enters the master password after login.
  security.pam.services = {
    gdm.enableGnomeKeyring = true;
    login.enableGnomeKeyring = true;
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

  # GNOME-specific portal backend. Merged with xdg-desktop-portal-gtk
  # declared in modules/system/hardware/flatpak.nix at evaluation time.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  # Disable the GNOME power settings daemon to avoid conflicts with TLP.
  # Both services manage CPU governors and battery thresholds; running
  # them simultaneously produces unpredictable power management behaviour.
  systemd.user.services.gsd-power.enable = false;
  systemd.user.services."org.gnome.SettingsDaemon.Power".enable = false;
}
