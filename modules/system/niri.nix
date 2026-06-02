# modules/system/niri.nix
#
# System-level configuration for the niri Wayland compositor session.
#
# Requires niri-flake.nixosModules.niri to be loaded in flake.nix (mkHost).
# That module registers niri as a session in GDM and provides
# programs.niri.enable.
#
# This module handles:
#   - Enabling the niri session (programs.niri.enable)
#   - Wayland portal configuration
#   - NVIDIA + Wayland environment variables (for PRIME sync on sukkub)
#   - polkit + dbus (required for non-GNOME sessions)
#   - Screenshot and clipboard tools
#
# Import from hosts/workstations/<hostname>/profile.nix.
{ pkgs, ... }: {

  # Register niri as a valid GDM session.
  # The actual per-user config (keybindings, layout) lives in
  # modules/home/desktop/niri.nix via programs.niri.settings.
  programs.niri.enable = true;

  security.polkit.enable = true;
  services.dbus.enable   = true;

  # xdg-desktop-portal: needed for screen sharing, file picker, etc.
  # gnome portal is kept as fallback alongside niri's own portal
  # (registered automatically by niri-flake when programs.niri.enable = true).
  xdg.portal = {
    enable        = true;
    extraPortals  = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = "gnome";
  };

  # NVIDIA Wayland environment variables (safe to set system-wide;
  # on Intel-only hosts like azazel these are harmless no-ops).
  environment.sessionVariables = {
    GBM_BACKEND               = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS   = "1";
    NIXOS_OZONE_WL            = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  environment.systemPackages = with pkgs; [
    polkit_gnome   # polkit auth agent for non-GNOME sessions
    wl-clipboard   # wl-copy / wl-paste (required by many apps)
    grim           # screenshot: capture screen or region
    slurp          # screenshot: interactive region selector
  ];
}
