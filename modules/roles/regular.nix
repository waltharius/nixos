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
  # Imports - MUST be at top level!
  # ==========================================
  imports =
    lib.optionals hasRegularRole (
      [
        # Desktop environment configuration
      ]
      ++ lib.optional (desktopPref == "gnome")
      ../home/desktop/gnome
      ++ lib.optional (desktopPref == "kde")
      ../home/desktop/kde
      ++ [
        # User's personal apps
        (../../users + "/${username}/apps.nix")

        # Desktop-specific customizations
      ]
      ++ lib.optional (desktopPref != null)
      (../../users + "/${username}/desktop/${desktopPref}")
    );

  # ==========================================
  # Configuration (empty for now, all done via imports)
  # ==========================================
  config = lib.mkIf hasRegularRole {
    # All configuration is handled by imported modules
    # This section is here for future role-specific settings
  };
}
