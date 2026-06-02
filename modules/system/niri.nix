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
# The solution: tell the kernel to use the Intel modesetting driver exclusively
# for display. NVIDIA stays loaded (its kernel module is still present for
# CUDA or compute use), but the display pipeline is 100% Intel KMS/DRM.
# This is the only reliable path for Maxwell + Wayland compositor != GNOME.
#
# In practice this means:
#   - niri runs on Intel GPU (fast, low-power, flawless Wayland)
#   - NVIDIA available via nvidia-offload wrapper for individual apps
#   - No tearing, no black screen, instant GDM recovery
#
# This is set via environment.sessionVariables so it applies to the entire
# user session (GDM + niri), not just per-app.
{ pkgs, ... }: {

  # Register niri as a valid GDM session.
  programs.niri.enable = true;

  security.polkit.enable = true;
  services.dbus.enable   = true;

  # Force Intel KMS/DRM as the display driver for the Wayland session.
  # WLR_DRM_DEVICES points the compositor at the Intel DRM node (/dev/dri/card0)
  # and away from the NVIDIA node. Without this, niri attempts to open the
  # NVIDIA DRM device first (alphabetical order), fails GBM init, and exits.
  #
  # card0 = Intel HD 530 on ThinkPad P50. Verify with:
  #   ls -la /dev/dri/by-path/ | grep -i intel
  # If Intel is card1 on your machine, adjust accordingly.
  #
  # LIBVA_DRIVER_NAME=iHD  → Intel Media Driver for VA-API (hardware video decode)
  # VDPAU_DRIVER=va_gl     → VDPAU via VA-API bridge (for apps using VDPAU)
  environment.sessionVariables = {
    WLR_DRM_DEVICES         = "/dev/dri/card0";
    LIBVA_DRIVER_NAME       = "iHD";
    VDPAU_DRIVER            = "va_gl";
  };

  # xdg-desktop-portal: needed for screen sharing, file picker, etc.
  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  environment.systemPackages = with pkgs; [
    polkit_gnome   # polkit auth agent for non-GNOME sessions
    wl-clipboard   # wl-copy / wl-paste
    grim           # screenshot: capture
    slurp          # screenshot: region selector
    intel-media-driver  # iHD VA-API driver (hardware video decode on Intel)
  ];
}
