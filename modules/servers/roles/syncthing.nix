# modules/servers/roles/syncthing.nix
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.server-role.syncthing;
in {
  options.services.server-role.syncthing = {
    enable = mkEnableOption "Syncthing";

    user = mkOption {
      type = types.str;
      default = "syncthing";
      description = "User to run Syncthing as";
    };

    group = mkOption {
      type = types.str;
      default = "syncthing";
      description = "Group for Syncthing user";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/mnt/syncthing-new";
      description = "Syncthing data directory (should be Proxmox mount)";
    };

    port = mkOption {
      type = types.port;
      default = 8384;
      description = "Web UI port";
    };
  };

  config = mkIf cfg.enable {
    # Create user/group if using default
    users.users.${cfg.user} = mkIf (cfg.user == "syncthing") {
      isSystemUser = true;
      group = cfg.group;
      home = mkForce cfg.dataDir;
      createHome = false; # Created by tmpfiles
    };

    users.groups.${cfg.group} = mkIf (cfg.group == "syncthing") {};

    # Create data directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Syncthing service
    services.syncthing = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      dataDir = cfg.dataDir;
      configDir = "${cfg.dataDir}/.config/syncthing";

      guiAddress = "0.0.0.0:${toString cfg.port}";

      settings = {
        gui = {
          insecureSkipHostcheck = true; # Behind reverse proxy
        };
      };

      overrideDevices = true;
      overrideFolders = true;
    };

    # Firewall
    networking.firewall = {
      allowedTCPPorts = [
        cfg.port # Web UI
        22000 # Sync protocol
      ];
      allowedUDPPorts = [
        22000 # Sync protocol
        21027 # Discovery
      ];
    };
  };
}
