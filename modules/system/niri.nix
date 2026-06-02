# modules/system/niri.nix
#
# System-level configuration required to run niri as a Wayland session.
#
# This module:
#   - Registers niri as a valid display-manager session
#   - Configures xdg-desktop-portal for Wayland screen sharing
#   - Sets environment variables needed for NVIDIA + Wayland (PRIME sync)
#   - Enables polkit so GUI apps can request elevated privileges
#
# Import this from the HOST profile (hosts/workstations/<name>/profile.nix).
# It is intentionally separate from the GNOME system module so both can
# coexist on the same host without conflict.
{
  pkgs,
  lib,
  ...
}: {
  # Register niri as a wayland session so GDM / greetd can offer it.
  programs.niri = {
    enable = true;
    # The actual configuration lives in the HM module (modules/home/desktop/niri.nix)
    # so it can be per-user. We only enable the session here.
  };

  # Polkit agent is required for GUI privilege escalation in a non-GNOME session.
  security.polkit.enable = true;

  # xdg-desktop-portal: screen sharing, file picker, etc.
  # gnome portal is kept as a fallback (works alongside wlr portal).
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome   # fallback / file picker
    ];
    # niri registers its own portal via programs.niri.enable; this just
    # ensures the GNOME fallback is always available.
    config.common.default = "gnome";
  };

  # NVIDIA + Wayland environment variables.
  # These are needed for niri to use the NVIDIA GPU correctly under PRIME sync.
  # GBM is the preferred buffer API for Wayland; EGL platform must be set
  # explicitly because NVIDIA's EGL doesn't auto-detect Wayland on 470.xx.
  environment.sessionVariables = {
    # Use GBM backend (required for niri on NVIDIA)
    GBM_BACKEND            = "nvidia-drm";
    # Force EGL to use the correct platform
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # Required for hardware-accelerated video decode on Wayland
    WLR_NO_HARDWARE_CURSORS = "1";
    # Hint Electron / Chromium apps to use Wayland natively
    NIXOS_OZONE_WL         = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  # dbus is required by most Wayland compositors and portals.
  services.dbus.enable = true;

  environment.systemPackages = with pkgs; [
    # polkit authentication agent for non-GNOME sessions
    polkit_gnome
    # Wayland clipboard support (required by many TUI/GUI apps)
    wl-clipboard
    # Screenshot tools
    grim    # capture a region or screen
    slurp   # interactive region selector (used with grim)
  ];
}
