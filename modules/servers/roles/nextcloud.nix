{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.server-role.nextcloud;
in {
  options.services.server-role.nextcloud = {
    enable = mkEnableOption "Nextcloud with MariaDB and Redis";

    hostname = mkOption {
      type = types.str;
      default = "cloud.home.lan";
      description = "Local hostname for Nextcloud";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/mnt/nextcloud-data";
      description = "Nextcloud data directory (should be Proxmox mountpoint)";
    };

    dbDataDir = mkOption {
      type = types.path;
      default = "/mnt/databases/mariadb";
      description = "MariaDB data directory (should be  Proxmox mountpoint)";
    };

    maxUploadSize = mkOption {
      type = types.str;
      default = "2G";
      description = "Maximum upload size for single file";
    };

    port = mkOption {
      type = types.port;
      default = "8080";
      description = "Port for Nextcloud (behind the proxy)";
    };
  };

  config = mkIf cfg.enable {
    # SOPS secrets
    sops.secrets = {
      nextcloud-admin-password = {
        sopsFile = ../../../secrets/nextcloud-admin-password.txt;
        format = "binary";
        owner = "nextcloud";
        mode = "0400";
      };
      nextcloud-db-password = {
        sopsFile = ../../../secrets/nextcloud-db-password.txt;
        format = "binary";
        owner = "nextcloud";
        mode = "0400";
      };
      mariadb-root-password = {
        sopsFile = ../../../secrets/mariadb-root-password.txt;
        format = "binary";
        owner = "mysql";
        mode = "0400";
      };
    };

    # Create database directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dbDataDir} 0750 mysql mysql - "
      "d ${cfg.dataDir} 0750 nextcloud nextcloud - "
    ];

    # MariaDB
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      dataDir = cfg.dbDataDir;

      ensureDatabases = ["nextcloud"];
      ensureUsers = [
        {
          name = "nextcloud";
          ensurePermissions = {
            "nextcloud.*" = "ALL PRIVILEGES";
          };
        }
      ];

      settings = {
        mysqld = {
          # Performance for Nextcloud
          innodb_buffer_pool_size = "2G";
          innodb_log_file_size = "512M";
          max_connections = 200;
          query_cache_size = "64M";
          query_cache_type = 1;
          tmp_table_size = "64M";
          max_heap_table_size = "64M";
        };
      };
    };

    # Redis for Nextcloud
    services.redis.servers.nextcloud = {
      enable = true;
      port = 6379;
      bind = "127.0.0.1";
      maxmemory = "256M";
      maxmemoryPolicy = "allkeys-lru";
    };

    # Nextcloud
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud32;
      phpPackage = pkgs.php84;

      hostName = cfg.hostName;
      datadir = cfg.dataDir;

      # Database
      database.createLocally = false;
      config = {
        dbtype = "mysql";
        dbname = "nextcloud";
        dbuser = "nextcloud";
        dbhost = "localhost:3306";
        dbpassFile = config.sops.secrets.nextcloud-db-password.path;

        adminuser = "admin";
        adminpassFile = config.sops.secrets.nextcloud-admin-password.path;
      };

      # HTTPS setup (behind the proxy [CADDY])
      https = true;

      # PHP settings
      phpOptions = {
        "upload_max_filesize" = cfg.maxUploadSize;
        "post_max_size" = cfg.maxUploadSize;
        "memory_limit" = "512M";
        "max_execution_time" = "300";
        "opcache.enable" = "1";
        "opcache.memory_consumption" = "128";
        "opcache.interned_strings_buffer" = "16";
        "opcache.max_accelerated_files" = "10000";
        "opcache.revalidate_freq" = "1";
      };

      # Nextcloud Apps setup declaratively
      # Use config.services.nextcloud.package for correct version
      extraApps = with config.services.nextcloud.package.packages.apps; {
        inherit calendar contacts tasks notes;
        inherit files_markdown files_texteditor;
        inherit deck;
      };
      extraAppsEnable = true;

      # Redis caching
      configureRedis = true;

      # Cron jobs
      autoUpdateApps = {
        enable = true;
        startAt = "05:00:00";
      };

      # Additional settings
      settings = {
        "overwriteprotocol" = "https";
        "default_phone_region" = "PL";
        "enable_previews" = true;
        "enabledPreviewProviders" = [
          "OC\\\\Preview\\\\PNG"
          "OC\\\\Preview\\\\JPEG"
          "OC\\\\Preview\\\\GIF"
          "OC\\\\Preview\\\\HEIC"
          "OC\\\\Preview\\\\BMP"
          "OC\\\\Preview\\\\XBitmap"
          "OC\\\\Preview\\\\MP3"
          "OC\\\\Preview\\\\TXT"
          "OC\\\\Preview\\\\MarkDown"
        ];
      };
    };

    # Nginx (Nextcloud module include this)
    services.nginx.virtualHost.${cfg.hostName} = {
      listen = [
        {
          addr = "0.0.0.0";
          port = cfg.port;
        }
      ];
      # Nextcloud module handles the rest
    };

    # Firewall
    networking.firewall.allowedTCPPorts = [cfg.port];

    # Background jobs
    systemd.services.nextcloud-cron = {
      description = "Nextcloud cron job";
      after = ["nextcloud-setup-service"];
      requires = ["nextcloud-setup-service"];

      serviceConfig = {
        Type = "oneshot";
        User = "nextcloud";
        ExecStart = "${config.services.nextcloud.package}/bin/nextcloud-occ background:cron";
      };
    };

    systemd.timers.nextcloud-cron = {
      description = "Run Nextcloud cron every 5 minutes";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBoorSec = "5m";
        OnUnitActiveSec = "5m";
        Unit = "nextcloud-cron.service";
      };
    };
  };
}
