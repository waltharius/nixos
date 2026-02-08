# modules/servers/roles/calibre-web.nix
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.server-role.calibre-web;
in {
  options.services.server-role.calibre-web = {
    enable = mkEnableOption "Calibre-web server";

    libraries = mkOption {
      type = types.listOf types.path;
      default = [];
      description = "List of Calibre library paths";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/calibre-web";
      description = "Data directory for Calibre-web config";
    };

    port = mkOption {
      type = types.port;
      default = 8083;
      description = "Web interface port";
    };

    user = mkOption {
      type = types.str;
      default = "calibre-web";
      description = "User to run Calibre-web as";
    };

    group = mkOption {
      type = types.str;
      default = "calibre-web";
      description = "Group for Calibre-web user";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall port for Calibre-web";
    };
  };

  config = mkIf cfg.enable {
    # User and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = false;
    };

    users.groups.${cfg.group} = {};

    # Create directories
    systemd.tmpfiles.rules =
      [
        "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      ]
      ++ (map (lib: "d ${lib} 0750 ${cfg.user} ${cfg.group} -") cfg.libraries);

    # Calibre-web service
    services.calibre-web = {
      enable = true;
      listen = {
        ip = "0.0.0.0";
        port = cfg.port;
      };
      options = {
        calibreLibrary = head cfg.libraries; # Primary library
        enableBookUploading = true;
        enableBookConversion = true;
      };
      user = cfg.user;
      group = cfg.group;
    };

    # Ensure storage is mounted before service starts
    systemd.services.calibre-web = {
      after = ["mnt-storage.mount"];
      requires = ["mnt-storage.mount"];
    };

    # Firewall
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
  };
}
