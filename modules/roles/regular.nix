# modules/roles/regular.nix
# Regular user role: desktop environment, full apps, media access

{ config, lib, pkgs, userConfig, customPkgs ? {}, ... }:

let
  username = userConfig.username;
  hasRegularRole = builtins.elem "regular" userConfig.roles;
  desktopPref = userConfig.desktopPreference;
in
{
  config = lib.mkIf hasRegularRole {
    # Also import maintainer tools (if user has both roles)
    imports = [
      # Desktop environment configuration
    ] ++ lib.optional (desktopPref == "gnome") 
           ../home/desktop/gnome
      ++ lib.optional (desktopPref == "kde")
           ../home/desktop/kde
      ++ [
        # User's personal apps
        (../../users + "/${username}/apps.nix")
        
        # Desktop-specific customizations
      ] ++ lib.optional (desktopPref != null)
           (../../users + "/${username}/desktop/${desktopPref}");
  };
}
