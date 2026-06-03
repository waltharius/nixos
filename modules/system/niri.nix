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
# The daemon exports SSH_AUTH_SOCK and GNOME_KEYRING_CONTROL into the
# systemd --user environment via systemd-environment-d-generator, making
# them available to all user services including Signal and Nextcloud.
#
# SIGNAL:
# Signal (Electron) uses the libsecret backend for its DB encryption key.
# With the keyring running and ELECTRON_OZONE_PLATFORM_HINT set, Signal
# finds gnome-libsecret automatically. The --password-store flag is set
# via the desktop entry wrapper in modules/system/brave.nix pattern.
#
# REGREET HIDPI:
# cage (the kiosk compositor hosting regreet) does not respect output
# scale from the compositor config. GDK_SCALE=2 forces GTK to render
# at 2x on the 4K eDP-1 panel. XCURSOR_SIZE=48 prevents a microscopic
# cursor. WLR_LIBINPUT_NO_DEVICES=0 ensures cage picks up input devices.
{ pkgs, lib, ... }: {

  programs.niri.enable = true;

  security.polkit.enable = true;
  services.dbus.enable   = true;

  # ---------------------------------------------------------------------------
  # GNOME Keyring via PAM
  # ---------------------------------------------------------------------------
  # enableGnomeKeyring injects pam_gnome_keyring.so into the greetd PAM stack.
  # On successful login it starts gnome-keyring-daemon, unlocks the "login"
  # keyring with the user password, and exports the socket paths into the
  # systemd --user environment. All secrets stored while using GNOME are
  # immediately accessible to niri session apps without any migration.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # ---------------------------------------------------------------------------
  # greetd + regreet + cage
  # ---------------------------------------------------------------------------
  services.greetd = {
    enable   = true;
    settings.default_session = {
      # cage: minimal Wayland kiosk compositor, hosts the regreet GTK4 UI.
      # -s  = handle VT switching
      # GDK_SCALE=2 is passed inline so the GTK4 greeter renders at HiDPI.
      # XCURSOR_SIZE=48 prevents microscopic cursor at 4K.
      command = lib.concatStringsSep " " [
        "env"
        "GDK_SCALE=2"
        "XCURSOR_SIZE=48"
        "${pkgs.cage}/bin/cage" "-s" "--"
        "${pkgs.greetd.regreet}/bin/regreet"
      ];
      user = "greeter";
    };
  };

  # WLR_DRM_DEVICES inherited by cage, regreet, and every spawned session.
  systemd.services.greetd.environment = {
    WLR_DRM_DEVICES = "/dev/dri/card1";
  };

  # ---------------------------------------------------------------------------
  # Session-wide environment variables
  # ---------------------------------------------------------------------------
  environment.variables = {
    # VA-API / VDPAU: Intel decode for all video consumers.
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER      = "va_gl";

    # Tell Electron apps (Signal, VSCode, …) to use Wayland natively.
    # This is required for libsecret/gnome-keyring to be found correctly;
    # under XWayland, Electron falls back to basic_text keyring backend.
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";

    # IBus: suppress the "IBus should be called from desktop session" popup.
    # niri does not use IBus; Polish keyboard layout is handled directly by
    # libxkbcommon via niri input.keyboard.xkb settings.
    GTK_IM_MODULE = "";
    QT_IM_MODULE  = "";
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
    libsecret           # secret-tool + gnome-keyring client library
  ];
}
