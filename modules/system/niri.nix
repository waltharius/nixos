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
#   - polkit + dbus (required for non-GNOME sessions)
#   - Screenshot and clipboard tools
#
# NVIDIA env vars are intentionally NOT set here.
# With PRIME offload (Intel drives the display), setting GBM_BACKEND=nvidia-drm
# or __GLX_VENDOR_LIBRARY_NAME=nvidia globally breaks GDM and any app that
# renders on Intel. These vars should only be set per-application via the
# nvidia-offload wrapper script provided by modules/laptop/nvidia.nix.
#
# Import from hosts/workstations/<hostname>/profile.nix.
#
# XDG portal note:
#   xdg.portal.config.common.default is intentionally NOT set here.
#   flatpak.nix owns that option (set to "*" via lib.mkDefault) so that
#   any DE-specific module can override it with lib.mkForce if needed.
#   Setting it in two places without priority annotations causes a
#   "conflicting definition values" evaluation error.
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
  # config.common.default is managed exclusively by flatpak.nix (mkDefault = "*")
  # to avoid conflicting definitions across modules.
  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  environment.systemPackages = with pkgs; [
    polkit_gnome   # polkit auth agent for non-GNOME sessions
    wl-clipboard   # wl-copy / wl-paste (required by many apps)
    grim           # screenshot: capture screen or region
    slurp          # screenshot: interactive region selector
  ];
}
