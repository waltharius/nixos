# modules/system/niri.nix
#
# System-level configuration for the niri Wayland compositor session.
#
# ARCHIVED — not imported by any host. Kept for future use.
#
# This module is self-contained: it imports niri-flake.nixosModules.niri
# itself, so a host profile only needs a single line:
#
#   imports = [ ../../../modules/system/niri.nix ];
#
# The HM configuration is NOT included here — it must be loaded separately
# in the host profile:
#
#   home-manager.users.marcin.imports = [
#     ../../../modules/home/desktop/niri.nix
#   ];
#
# WHY SEPARATE?
#   niri-flake.nixosModules.niri used to auto-inject homeModules.niri
#   into every home-manager user when loaded globally. Now that we load
#   it only per-host, the auto-injection still happens — but only for
#   that host. However, modules/home/desktop/niri.nix also explicitly
#   imports homeModules.niri to be safe and self-documenting.
#   Do NOT add homeModules.niri to flake.nix sharedModules.
#
# NEVER IMPORT BOTH gnome.nix AND niri.nix ON THE SAME HOST.
#   Each owns the display manager. The assertion below will catch it.
#
# NVIDIA DRM NODE ORDER ON THINKPAD P50:
#   /dev/dri/card0  -> pci-0000:01:00.0 -> NVIDIA Quadro M2000M  (legacy_470)
#   /dev/dri/card1  -> pci-0000:00:02.0 -> Intel HD Graphics 530 (i915)
#   WLR_DRM_DEVICES must point to card1 (Intel iGPU).
#
# GNOME KEYRING:
#   gnome-keyring-daemon is started via PAM at login (pam_gnome_keyring.so).
#   All existing secrets (Nextcloud OAuth tokens, SSH keys) are unlocked
#   automatically when the user logs in through greetd.
#
# SIGNAL:
#   ELECTRON_OZONE_PLATFORM_HINT=wayland forces Electron apps into native
#   Wayland mode. Under XWayland, Electron cannot find the DBus session
#   and falls back to basic_text keyring backend.
#
# REGREET HIDPI:
#   GDK_SCALE=2 + XCURSOR_SIZE=48 passed inline to cage so the GTK4 greeter
#   is readable on the 4K eDP-1 panel.
#
# IBUS / GTK_IM_MODULE:
#   services.desktopManager.gnome.enable pulls in ibus and sets
#   GTK_IM_MODULE="ibus" via i18n.inputMethod. We override it to empty
#   with lib.mkForce so niri sessions are not affected.
{ pkgs, lib, config, inputs, ... }:

let
  # Catch accidental double-import with gnome.nix at evaluation time.
  # gnome.nix sets gdm.enable = true; if that is already set when we
  # arrive here, the two modules were imported together, which will
  # produce two conflicting display managers.
  gdmAlsoEnabled = config.services.displayManager.gdm.enable;
in
{
  imports = [
    # Pull in the upstream niri NixOS module. This registers niri as a
    # Wayland session and provides the programs.niri.enable option.
    # It also auto-injects homeModules.niri for any home-manager user
    # on this host — so do NOT add homeModules.niri to sharedModules
    # in flake.nix, that would cause a duplicate-option build error.
    inputs.niri-flake.nixosModules.niri
  ];

  assertions = [{
    assertion = !gdmAlsoEnabled;
    message   = ''
      modules/system/niri.nix: GDM is enabled alongside greetd.
      Do NOT import both modules/system/desktop/gnome.nix and niri.nix.
      Only one display manager may be active at a time.
    '';
  }];

  programs.niri.enable = true;

  security.polkit.enable = true;
  services.dbus.enable   = true;

  # Explicitly disable GDM — this module owns the display manager.
  services.displayManager.gdm.enable = false;

  # ---------------------------------------------------------------------------
  # GNOME Keyring via PAM (greetd owns the session unlock here)
  # ---------------------------------------------------------------------------
  services.gnome.gnome-keyring.enable                   = true;
  security.pam.services.greetd.enableGnomeKeyring       = true;

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
    regreet             # GTK4 greeter for greetd
    libsecret           # secret-tool + gnome-keyring client library
  ];
}
