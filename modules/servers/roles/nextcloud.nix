# modules/servers/roles/nextcloud.nix
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
      default = 8080;
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
      "d ${cfg.dataDir}/config 0750 nextcloud nextcloud - "
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

      # Memory and eviction policy in settings
      settings = {
        maxmemory = "256M";
        maxmemory-policy = "allkeys-lru";
      };
    };

    # Nextcloud
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud32;
      phpPackage = pkgs.php83; # PHP 8.3 recommended for Nextcloud 32

      hostName = cfg.hostname;
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

      # PHP settings - use mkForce to overwrite NixOS defaults
      phpOptions = {
        "upload_max_filesize" = mkForce cfg.maxUploadSize;
        "post_max_size" = mkForce cfg.maxUploadSize;
        "memory_limit" = mkForce "512M";
        "max_execution_time" = mkForce "300";
        "opcache.enable" = mkForce "1";
        "opcache.memory_consumption" = mkForce "128";
        "opcache.interned_strings_buffer" = mkForce "16";
        "opcache.max_accelerated_files" = mkForce "10000";
        "opcache.revalidate_freq" = mkForce "1";
      };

      # Nextcloud Apps setup declaratively
      # Use config.services.nextcloud.package for correct version
      # To find available apps: nix repl -> :l <nixpkgs> -> pkgs.nextcloud32Packages.apps.<TAB>
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # Productivity apps
        inherit bookmarks qownnotesapi calendar contacts tasks notes;
        # Collaboration
        inherit deck onlyoffice;
        # Additional apps can be installed via web UI
      };
      extraAppsEnable = true;

      # Redis caching
      configureRedis = true;

      # Cron jobs - NixOS Nextcloud module handles this automatically!
      # No need to create custom cron service/timer
      autoUpdateApps = {
        enable = true;
        startAt = "05:00:00";
      };

      # Additional settings
      settings = {
        trusted_domains = [
          "cloud.home.lan"
          "stuff.deranged.cc"
        ];
        "overwriteprotocol" = "https";
        "overwrite.cli.url" = "https://cloud.home.lan";

        "trusted_proxies" = ["192.168.50.114"];
        "forwarded_for_headers" = [
          "HTTP_X_FORWARDED_FOR"
          "HTTP_X_REAL_IP"
        ];

        "maintenance_window_start" = 3;
        "log_type" = "file";
        "logfile" = "${cfg.dataDir}/nextcloud.log";
        "loglevel" = 2;
        "log_rotate_size" = "104857600";

        "app_api.enabled" = false;
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

    # Nginx - virtualHosts (plural!)
    services.nginx.virtualHosts.${cfg.hostname} = {
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

    # systemd.services.nextcloud-update-db.enable = mkForce false;

    # Note: NixOS Nextcloud module automatically creates:
    # - systemd.services.nextcloud-cron.service
    # - systemd.timers.nextcloud-cron.timer
    # These run every 5 minutes to handle background jobs.
    # You don't need to create them manually!
  };
}
