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
# In practice this means:
#   - niri runs on Intel GPU (fast, low-power, flawless Wayland)
#   - NVIDIA available via nvidia-offload wrapper for individual apps
#   - No tearing, no black screen, instant GDM recovery
{ pkgs, ... }: {

  # Register niri as a valid GDM session.
  programs.niri.enable = true;

  security.polkit.enable = true;
  services.dbus.enable   = true;

  # Force niri to use the Intel DRM node.
  # card1 = Intel HD 530 on ThinkPad P50 (counter-intuitive — see note above).
  # Without this, wlroots opens card0 (NVIDIA) first, GBM init fails with
  # legacy_470, and the compositor exits before rendering anything.
  #
  # LIBVA_DRIVER_NAME=iHD  -> Intel Media Driver for VA-API (hw video decode)
  # VDPAU_DRIVER=va_gl     -> VDPAU via VA-API bridge
  environment.sessionVariables = {
    WLR_DRM_DEVICES   = "/dev/dri/card1";
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
