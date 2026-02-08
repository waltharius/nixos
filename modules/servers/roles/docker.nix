# modules/servers/roles/docker.nix
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.server-role.docker;
in {
  options.services.server-role.docker = {
    enable = mkEnableOption "Docker container runtime";

    dataRoot = mkOption {
      type = types.path;
      default = "/var/lib/docker";
      description = "Docker data directory (use external storage for production)";
    };

    enableAutoPrune = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically prune unused containers and images";
    };

    pruneSchedule = mkOption {
      type = types.str;
      default = "weekly";
      description = "systemd timer schedule for auto-prune";
    };

    allowedUsers = mkOption {
      type = types.listOf types.str;
      default = ["nixadm"];
      description = "Users who can access Docker socket";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;

      daemon.settings = {
        data-root = cfg.dataRoot;

        # Optimize for resource management
        default-ulimits = {
          memlock = {
            Hard = -1;
            Soft = -1;
          };
        };

        # Logging configuration to prevent disk filling
        log-driver = "json-file";
        log-opts = {
          max-size = "10m";
          max-file = "3";
        };
      };

      autoPrune = mkIf cfg.enableAutoPrune {
        enable = true;
        dates = cfg.pruneSchedule;
        flags = ["--all" "--volumes"];
      };
    };

    # Grant users Docker access
    users.users = listToAttrs (map (user: {
        name = user;
        value = {extraGroups = ["docker"];};
      })
      cfg.allowedUsers);

    # Ensure data directory exists and is mounted
    systemd.services.docker = mkIf (cfg.dataRoot != "/var/lib/docker") {
      after = ["mnt-storage.mount"];
      requires = ["mnt-storage.mount"];
    };
  };
}
