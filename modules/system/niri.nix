# modules/system/niri.nix
#
# System-level configuration for the niri Wayland compositor session.
# Owns: greetd display manager, gnome-keyring PAM integration, env vars.
#
# NVIDIA DRM NODE ORDER ON THINKPAD P50:
#   /dev/dri/card0  -> pci-0000:01:00.0 -> NVIDIA Quadro M2000M  (legacy_470)
#   /dev/dri/card1  -> pci-0000:00:02.0 -> Intel HD Graphics 530 (i915)
# WLR_DRM_DEVICES must point to card1 (Intel).
#
# GNOME KEYRING:
# gnome-keyring-daemon is started via PAM at login (pam_gnome_keyring.so).
# This is identical to how GNOME starts it, so all existing secrets
# (Nextcloud OAuth tokens, SSH keys, Signal DB key) are unlocked
# automatically when the user logs in through greetd.
#
# SIGNAL:
# ELECTRON_OZONE_PLATFORM_HINT=wayland forces Electron apps into native
# Wayland mode. Under XWayland, Electron cannot find the DBus session
# and falls back to basic_text keyring backend, losing access to secrets.
# The --password-store=gnome-libsecret flag is set in the niri keybind.
#
# REGREET HIDPI:
# GDK_SCALE=2 + XCURSOR_SIZE=48 passed inline to cage so the GTK4 greeter
# is readable on the 4K eDP-1 panel.
#
# IBUS / GTK_IM_MODULE:
# services.desktopManager.gnome.enable pulls in ibus and sets
# GTK_IM_MODULE="ibus" via i18n.inputMethod. We override it to empty
# with lib.mkForce so niri sessions are not affected. GNOME sessions
# re-set it themselves via gnome-session environment.
{ pkgs, lib, ... }: {

  programs.niri.enable = true;

  security.polkit.enable = true;
  services.dbus.enable   = true;

  # ---------------------------------------------------------------------------
  # GNOME Keyring via PAM
  # ---------------------------------------------------------------------------
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # ---------------------------------------------------------------------------
  # greetd + regreet + cage
  # ---------------------------------------------------------------------------
  services.greetd = {
    enable   = true;
    settings.default_session = {
      # GDK_SCALE=2: regreet (GTK4) renders at HiDPI on the 4K panel.
      # XCURSOR_SIZE=48: prevents microscopic cursor.
      command = lib.concatStringsSep " " [
        "env"
        "GDK_SCALE=2"
        "XCURSOR_SIZE=48"
        "${pkgs.cage}/bin/cage" "-s" "--"
        "${pkgs.regreet}/bin/regreet"
      ];
      user = "greeter";
    };
  };

  # WLR_DRM_DEVICES inherited by cage, regreet, and every spawned session.
  systemd.services.greetd.environment = {
    WLR_DRM_DEVICES = "/dev/dri/card1";
  };

  # ---------------------------------------------------------------------------
  # Session-wide environment
  # ---------------------------------------------------------------------------
  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER      = "va_gl";

    # Native Wayland for Electron: required for libsecret/gnome-keyring
    # to be found. Under XWayland the DBus session is not visible to Electron.
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";

    # IBus is pulled in by services.desktopManager.gnome and sets
    # GTK_IM_MODULE="ibus" system-wide. Override to empty so niri sessions
    # don't try to connect to an IBus daemon that isn't running.
    # lib.mkForce is required because ibus.nix sets this with normal priority.
    GTK_IM_MODULE = lib.mkForce "";
    QT_IM_MODULE  = lib.mkForce "";
  };

  # ---------------------------------------------------------------------------
  # XDG portal
  # ---------------------------------------------------------------------------
  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  environment.systemPackages = with pkgs; [
    polkit_gnome        # polkit auth agent for non-GNOME sessions
    wl-clipboard        # wl-copy / wl-paste
    grim                # screenshot: capture
    slurp               # screenshot: region selector
    intel-media-driver  # iHD VA-API driver
    cage                # kiosk compositor for regreet
    regreet             # GTK4 greeter for greetd (renamed from greetd.regreet in 26.05)
    libsecret           # secret-tool + gnome-keyring client library
  ];
}
