# modules/roles/regular.nix
# Regular user role: desktop environment, full apps, media access
{
  lib,
  userConfig,
  customPkgs ? {},
  ...
}: let
  username = userConfig.username;
  hasRegularRole = builtins.elem "regular" userConfig.roles;
  desktopPref = userConfig.desktopPreference;
in {
  # ==========================================
  # Imports - ALWAYS import (activation is conditional)
  # ==========================================
  imports =
    [
      # User's personal apps (will only activate if regular role)
      (../../users + "/${username}/apps.nix")
    ]
    # Desktop-specific imports (GNOME or KDE)
    ++ lib.optional (desktopPref == "gnome") ../home/desktop/gnome
    ++ lib.optional (desktopPref == "kde") ../home/desktop/kde
    ++ lib.optional (desktopPref == "gnome") (../../users + "/${username}/desktop/gnome")
    ++ lib.optional (desktopPref == "kde") (../../users + "/${username}/desktop/kde");

  # ==========================================
  # Configuration - Placeholder for future settings
  # ==========================================
  config = lib.mkIf hasRegularRole {
    # All configuration is handled by imported modules
    # User apps in apps.nix activate based on being imported
    # Desktop modules (GNOME/KDE) activate based on being imported
  };
}
