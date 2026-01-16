# modules/system/user-roles.nix
# Core role-based user management system
{
  config,
  lib,
  ...
}: let
  userAssignments = config.hostUsers or {};

  # Collect all requested DEs from users with "regular" role
  requestedDEs = lib.unique (
    lib.filter (de: de != null)
    (lib.mapAttrsToList (
        name: cfg:
          if builtins.elem "regular" cfg.roles
          then cfg.desktopPreference
          else null
      )
      userAssignments)
  );
in {
  options.hostUsers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
      options = {
        roles = lib.mkOption {
          type = lib.types.listOf (lib.types.enum ["regular" "maintainer"]);
          default = [];
          description = "Roles for this user on this host";
          example = ["regular" "maintainer"];
        };

        desktopPreference = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["gnome" "kde"]);
          default = null;
          description = "Desktop environment preference (only with 'regular' role)";
        };

        isServer = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Is this a server environment (affects starship prompt)";
        };

        sshKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "SSH public keys for this user";
        };

        description = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "User description";
        };
      };
    }));
    default = {};
    description = "User assignments for this host";
  };

  config = {
    # Install requested DEs at system level (only if users need them)
    imports =
      lib.optional (builtins.elem "gnome" requestedDEs)
      ./desktop-environments/gnome.nix
      ++ lib.optional (builtins.elem "kde" requestedDEs)
      ./desktop-environments/kde.nix;

    # Create system users
    users.users =
      lib.mapAttrs (username: userCfg: {
        isNormalUser = true;
        description = userCfg.description;

        # Build extraGroups based on roles
        extraGroups =
          ["networkmanager"]
          ++
          # Maintainer role gets wheel (sudo)
          lib.optional (builtins.elem "maintainer" userCfg.roles) "wheel"
          ++
          # Regular role gets media and hardware access
          lib.optionals (builtins.elem "regular" userCfg.roles)
          ["video" "audio" "input" "uinput" "plugdev"];

        openssh.authorizedKeys.keys = userCfg.sshKeys;
      })
      userAssignments;

    # Configure home-manager for each user
    home-manager.users =
      lib.mapAttrs (
        username: userCfg: {...}: {
          imports = [
            # User's personal identity (always)
            (../../users + "/${username}/identity.nix")

            # Role modules (both imported, each activates based on roles)
            ../../modules/roles/regular.nix
            ../../modules/roles/maintainer.nix
          ];

          # Pass user config to role modules
          _module.args.userConfig = userCfg // {inherit username;};
        }
      )
      userAssignments;
  };
}
