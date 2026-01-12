{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.server-role.actual-budget;
in {
  options.services.server-role.actual-budget = {
    enable = mkEnableOption "Actual Budget server role";

    port = mkOption {
      type = types.port;
      default = 5006;
      description = "Port for Actual Budget server";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/actual-budget";
      description = "Data directory for Actual Budget";
    };

    domain = mkOption {
      type = types.str;
      default = "actual.home.lan";
      description = "Domain name for Actual Budget";
    };
  };

  config = mkIf cfg.enable {
    # Install Actual Budget server
    environment.systemPackages = [pkgs.actual-server];

    # Create systemd service
    systemd.services.actual-budget = {
      description = "Actual Budget Server";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = "actual";
        Group = "actual";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${pkgs.actual-server}/bin/actual-server";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [cfg.dataDir];
      };

      environment = {
        ACTUAL_PORT = toString cfg.port;
        ACTUAL_DATA_DIR = cfg.dataDir;
      };
    };

    # Create user and group
    users.users.actual = {
      isSystemUser = true;
      group = "actual";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.actual = {};

    # Open firewall port
    networking.firewall.allowedTCPPorts = [cfg.port];

    # Data directory permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 actual actual -"
    ];
  };
}
