# modules/system/hardware/flatpak.nix
#
# Flatpak sandboxed application runtime + XDG Desktop Portals.
#
# Extracted from modules/system/desktop/gnome.nix so that Flatpak is
# available regardless of which desktop environment is active.
#
# Flatpak and XDG portals are distinct but complementary:
#   - Flatpak provides the sandboxed packaging and runtime.
#   - XDG portals are the IPC bridge that lets sandboxed applications
#     (Flatpak, but also native Wayland apps) request OS-level operations
#     (file picker, screenshot, print, etc.) without breaking out of the
#     sandbox. Each desktop environment ships its own portal backend.
#
# xdg-desktop-portal-gtk is included here as a universal fallback. It
# handles GTK-native dialogs (file chooser, colour picker) for applications
# that do not have a DE-specific portal available. The DE-specific portal
# (e.g. xdg-desktop-portal-gnome) is added by the respective desktop module
# via an additive extraPortals list — the NixOS module system merges lists
# automatically, so there is no duplication.
#
# xdg.portal.config.common.default is set here with lib.mkDefault so that
# other modules (e.g. desktop-specific ones) can override it with lib.mkForce
# without triggering a "conflicting definition values" evaluation error.
# Using plain "=" assignment in two modules causes that error even when the
# values are identical, because Nix treats them as independent definitions.
{ lib, pkgs, ... }: {
  services.flatpak.enable = true;

  xdg.portal = {
    enable = true;
    # GTK portal acts as a universal fallback for all desktop environments.
    # DE-specific portals are appended by their respective desktop modules.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # lib.mkDefault allows DE-specific modules to override this value.
    # Never use a plain assignment here — any other module setting the same
    # option without a priority annotation will cause an evaluation error.
    config.common.default = lib.mkDefault "*";
  };
}
