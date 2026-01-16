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
  # Imports - ALWAYS import everything unconditionally!
  # Each module will check internally if it should activate
  # ==========================================
  imports = [
    # User's personal apps
    (../../users + "/${username}/apps.nix")

    # Desktop modules - import both, they'll check desktopPreference internally
    ../home/desktop/gnome
    ../home/desktop/kde

    # User's desktop customizations - import both if they exist
    # They will check internally if they should activate
  ];

  # ==========================================
  # Configuration
  # ==========================================
  config = lib.mkIf hasRegularRole {
    # All configuration is handled by imported modules
    # Apps and desktop modules activate based on their own conditions
  };
}
