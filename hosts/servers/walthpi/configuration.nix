# hosts/servers/walthpi/configuration.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../../modules/system/certificates.nix
    ../../../modules/system/secrets.nix
    ../../../modules/servers/users.nix
    ../../../modules/servers/roles/calibre-web.nix
    ../../../modules/servers/roles/checkmk-agent.nix
    ../../../modules/servers/roles/docker.nix
    ../../../modules/servers/roles/raspberry-pi-hardware.nix
  ];

  # Basic system settings
  networking = {
    hostName = "walthpi";
    domain = "home.lan";
    useDHCP = false;
    interfaces.end0.ipv4.addresses = [
      {
        address = "192.168.50.47";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.50.1";
    nameservers = ["192.168.50.1"]; # FreeIPA DNS

    firewall.enable = true;
  };

  # Raspberry Pi hardware optimizations
  hardware.raspberry-pi-optimizations = {
    enable = true;
    enableZRAM = true;
    zramSize = 50;
    enableTempMonitoring = true;
  };

  # Calibre-web service with both libraries
  services.server-role.calibre-web = {
    enable = true;
    libraries = [
      "/mnt/storage/calibre/Pi_Library"
      "/mnt/storage/calibre/Study_Library"
    ];
    port = 8083;
    openFirewall = true; # For local network access
  };

  # Check_MK monitoring
  services.server-role.checkmk-agent = {
    enable = true;
    allowedIPs = ["192.168.50.0/24"]; # Your Proxmox network
  };

  # Docker for utility containers
  services.server-role.docker = {
    enable = true;
    dataRoot = "/mnt/storage/docker";
    enableAutoPrune = true;
    allowedUsers = ["nixadm"];
  };

  # Nix settings for ARM
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["nixadm" "root" "@wheel"];

    # Build locally on RPi (slow but works)
    max-jobs = 2;
    cores = 2;

    # Aggressive cleanup for limited SD space
    keep-outputs = false;
    keep-derivations = false;
    auto-optimise-store = true;
  };

  # Essential packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    btop
    curl
    wget
    rsync
    bind
    killall
  ];

  # SSH server
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Automatic maintenance
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d"; # Aggressive for SD card
  };

  nix.optimise = {
    automatic = true;
    dates = ["weekly"];
  };

  # Locale settings
  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";

  sops = {
    defaultSopsFile = ../../../secrets/walthpi.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };

  system.stateVersion = "25.11";
}
