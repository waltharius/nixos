# modules/system/niri.nix
#
# System-level configuration for the niri Wayland compositor session.
#
# NVIDIA + niri: why we force Intel modesetting
# ---------------------------------------------
# ThinkPad P50 has PRIME hybrid graphics (Intel HD 530 + Quadro M2000M).
# The NVIDIA legacy_470 driver (required for Maxwell) has broken GBM support
# for non-GNOME Wayland compositors in PRIME modes. Both sync and offload
# modes result in a black screen when niri tries to init the DRM device,
# because legacy_470 does not properly export a GBM backend that niri can use.
#
# The solution: tell the compositor to use the Intel DRM node exclusively.
# NVIDIA stays loaded (its kernel module is still present for CUDA/compute),
# but the display pipeline is 100% Intel KMS/DRM.
#
# IMPORTANT: On ThinkPad P50 the DRM node order is counter-intuitive:
#   /dev/dri/card0  -> pci-0000:01:00.0 -> NVIDIA Quadro M2000M
#   /dev/dri/card1  -> pci-0000:00:02.0 -> Intel HD Graphics 530
# Verified via /dev/dri/by-path symlinks and readlink on each card node.
# WLR_DRM_DEVICES must point to card1 (Intel) NOT card0 (NVIDIA).
#
# WHY NOT environment.sessionVariables?
# environment.sessionVariables is read by PAM/pam_env when a user session
# starts — i.e. AFTER GDM has already launched the session binary.
# GDM itself (the display manager process, running as root / gdm user)
# never sees those variables. The session binary (niri) is spawned by GDM
# with GDM's own environment, which does not include sessionVariables.
#
# The correct mechanism is environment.variables (sets /etc/environment,
# read system-wide by PAM before any session starts, including GDM's own
# child processes) combined with a GDM environment.d drop-in for the
# variables that must be visible to the Wayland compositor subprocess.
#
# environment.variables is used here for LIBVA/VDPAU (safe globally).
# WLR_DRM_DEVICES is injected via a systemd environment.d drop-in placed
# in /etc/systemd/system/gdm.service.d/ so that GDM exports it to every
# session it spawns, including niri.
{ pkgs, lib, ... }: {

  # Register niri as a valid GDM session.
  programs.niri.enable = true;

  security.polkit.enable = true;
  services.dbus.enable   = true;

  # Inject WLR_DRM_DEVICES into GDM's environment so that every session
  # GDM spawns (including niri) inherits it before the compositor inits DRM.
  # This is the only reliable way to influence wlroots DRM device selection
  # when the session is launched by a display manager.
  #
  # card1 = Intel HD 530 on ThinkPad P50.
  # Without this niri opens card0 (NVIDIA), GBM init fails, black screen.
  systemd.services.gdm.serviceConfig.Environment = [
    "WLR_DRM_DEVICES=/dev/dri/card1"
  ];

  # LIBVA and VDPAU are safe to set globally — they only affect VA-API/VDPAU
  # consumers (video players, browsers) and do not influence display init.
  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER      = "va_gl";
  };

  # xdg-desktop-portal: needed for screen sharing, file picker, etc.
  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  environment.systemPackages = with pkgs; [
    polkit_gnome        # polkit auth agent for non-GNOME sessions
    wl-clipboard        # wl-copy / wl-paste
    grim                # screenshot: capture
    slurp               # screenshot: region selector
    intel-media-driver  # iHD VA-API driver (hardware video decode on Intel)
  ];
}
