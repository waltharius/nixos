# modules/system/niri.nix
#
# System-level configuration for the niri Wayland compositor session.
#
# This module also owns the display manager configuration (greetd + regreet).
#
# WHY GREETD INSTEAD OF GDM?
# GDM is tightly coupled to GNOME/Mutter and has a persistent bug on NVIDIA
# PRIME hybrid systems: it does not reliably pass environment variables such
# as WLR_DRM_DEVICES to non-GNOME Wayland sessions it spawns. The result is
# a black screen regardless of how the variable is set (sessionVariables,
# environment.d drop-ins, gdm.serviceConfig.Environment).
#
# greetd spawns the session as the target user in a clean PAM session, with
# full control over the environment. Combined with a tuigreet wrapper script
# that exports WLR_DRM_DEVICES before exec-ing niri, this is 100% reliable.
#
# NVIDIA DRM NODE ORDER ON THINKPAD P50:
#   /dev/dri/card0  -> pci-0000:01:00.0 -> NVIDIA Quadro M2000M  (legacy_470)
#   /dev/dri/card1  -> pci-0000:00:02.0 -> Intel HD Graphics 530 (i915)
# The NVIDIA driver initialises earlier in the boot sequence and claims card0.
# WLR_DRM_DEVICES must be set to card1 so niri/wlroots skips the NVIDIA node
# (whose GBM implementation is broken in legacy_470) and uses Intel instead.
#
# GREETER SELECTION: regreet (GTK4 greeter for greetd)
# regreet lists all installed Wayland/X11 sessions from /run/current-system
# and lets the user pick. Both niri and gnome-wayland are available.
{ pkgs, lib, ... }: {

  # Register niri as a valid session entry in /run/current-system/sw/share/wayland-sessions/.
  programs.niri.enable = true;

  security.polkit.enable = true;
  services.dbus.enable   = true;

  # ---------------------------------------------------------------------------
  # greetd display manager
  # ---------------------------------------------------------------------------
  # greetd runs as a systemd service, starts regreet (a GTK4 greeter) which
  # renders on the Intel DRM node. WLR_DRM_DEVICES is set inside the
  # greetd environment via the environment option so it is inherited by
  # the greeter AND by every session greetd spawns.
  services.greetd = {
    enable   = true;
    settings = {
      default_session = {
        # regreet is a GTK4 greeter that needs a Wayland compositor to run on.
        # We launch it inside cage (a minimal Wayland kiosk compositor) which
        # correctly initialises on Intel DRM without any NVIDIA involvement.
        command = lib.concatStringsSep " " [
          "${pkgs.cage}/bin/cage"
          "-s" "--"
          "${pkgs.greetd.regreet}/bin/regreet"
        ];
        user = "greeter";
      };
    };
  };

  # Inject WLR_DRM_DEVICES into greetd's own environment.
  # greetd inherits this into cage (the greeter compositor) and into
  # every user session it spawns, so niri always opens card1 (Intel).
  systemd.services.greetd.environment = {
    WLR_DRM_DEVICES = "/dev/dri/card1";
  };

  # Allow regreet to write its state (last-selected session / user).
  environment.etc."greetd/environments".text = '';

  # VA-API / VDPAU: safe to set globally, only affects video decode consumers.
  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER      = "va_gl";
  };

  # xdg-desktop-portal: screen sharing, file picker, etc.
  # config.common.default is managed by flatpak.nix (lib.mkDefault = "*").
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
    cage                # minimal Wayland compositor used by regreet greeter
  ];
}
