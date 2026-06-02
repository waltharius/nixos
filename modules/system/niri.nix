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
# full control over the environment. Combined with WLR_DRM_DEVICES injected
# into greetd's systemd environment, this is 100% reliable.
#
# NVIDIA DRM NODE ORDER ON THINKPAD P50:
#   /dev/dri/card0  -> pci-0000:01:00.0 -> NVIDIA Quadro M2000M  (legacy_470)
#   /dev/dri/card1  -> pci-0000:00:02.0 -> Intel HD Graphics 530 (i915)
# The NVIDIA driver initialises earlier in the boot sequence and claims card0.
# WLR_DRM_DEVICES must be set to card1 so niri/wlroots skips the NVIDIA node
# (whose GBM implementation is broken in legacy_470) and uses Intel instead.
#
# GREETER: regreet (GTK4) running inside cage (minimal kiosk compositor).
# regreet lists all installed sessions from /run/current-system/sw/share/
# wayland-sessions/. Both niri and gnome-wayland will be visible.
{ pkgs, lib, ... }: {

  # Register niri as a valid session entry.
  programs.niri.enable = true;

  security.polkit.enable = true;
  services.dbus.enable   = true;

  # ---------------------------------------------------------------------------
  # greetd display manager
  # ---------------------------------------------------------------------------
  services.greetd = {
    enable   = true;
    settings = {
      default_session = {
        # cage: minimal Wayland kiosk compositor, hosts the regreet GTK4 UI.
        # Initialises correctly on Intel DRM without any NVIDIA involvement.
        command = lib.concatStringsSep " " [
          "${pkgs.cage}/bin/cage"
          "-s" "--"
          "${pkgs.greetd.regreet}/bin/regreet"
        ];
        user = "greeter";
      };
    };
  };

  # WLR_DRM_DEVICES in greetd's systemd environment is inherited by cage,
  # regreet, and every user session greetd spawns — including niri.
  systemd.services.greetd.environment = {
    WLR_DRM_DEVICES = "/dev/dri/card1";
  };

  # VA-API / VDPAU: safe to set globally, only affects video decode.
  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER      = "va_gl";
  };

  # xdg-desktop-portal: screen sharing, file picker, etc.
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
