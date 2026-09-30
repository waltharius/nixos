# modules/groups/gnome/nixos.nix
#
# Group `gnome`, system part: GNOME with GDM. Imported on a host as soon
# as any of its users has the `gnome` group.
#
# Audio, printing and Flatpak are not part of this group: every
# workstation gets them (lib/classes.nix), whatever desktop its users run.
#
# services.xserver.enable is kept because autoRepeatDelay and
# autoRepeatInterval are wired to the X11 input layer in NixOS 26.05
# and remain effective for Wayland sessions via the XKB subsystem.
#
# gcr-ssh-agent (GNOME 44+) supersedes the legacy SSH agent in
# gnome-keyring. programs.ssh.startAgent must be false.
{pkgs, ...}: {
  services.xserver = {
    enable = true;
    autoRepeatDelay = 200;
    autoRepeatInterval = 35;
  };

  services.displayManager.gdm.enable = true;

  services.desktopManager.gnome = {
    enable = true;
    extraGSettingsOverridePackages = [pkgs.mutter];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

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

  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gnome];

  # Terminal of the GNOME session, available to every user of the host.
  environment.systemPackages = [pkgs.ptyxis];

  systemd.user.services.gsd-power.enable = false;
  systemd.user.services."org.gnome.SettingsDaemon.Power".enable = false;
}
