# hosts/servers/cloud-apps/configuration.nix
{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../../modules/servers/base-lxc.nix
    ../../../modules/servers/roles/nextcloud.nix
    ../../../modules/servers/roles/syncthing.nix
  ];

  networking.hostName = "cloud-apps";
  system.stateVersion = "25.11";

  # Nextcloud with MariaDB and Redis
  services.server-role.nextcloud = {
    enable = true;
    hostname = "cloud.home.lan";
    dataDir = "/mnt/nextcloud-data";
    dbDataDir = "/mnt/databases/mariadb";
    maxUploadSize = "5G"; # Adjust as needed
    port = 8080;
  };

  # Syncthing (separate user for security)
  services.server-role.syncthing = {
    enable = true;
    user = "syncthing";
    group = "syncthing";
    dataDir = "/mnt/syncthing-new";
    port = 8384;
  };

  # Additional packages for database management
  environment.systemPackages = with pkgs; [
    mariadb
    redis
  ];

  # Ensure mount points exist in config
  fileSystems = {
    "/mnt/nextcloud-data" = {
      device = "/mnt/nextcloud-data";
      fsType = "none";
      options = ["bind"];
    };
    "/mnt/syncthing-new" = {
      device = "/mnt/syncthing-new";
      fsType = "none";
      options = ["bind"];
    };
    "/mnt/databases" = {
      device = "/mnt/databases";
      fsType = "none";
      options = ["bind"];
    };
  };
}
