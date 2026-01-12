# Base configuration for all LXC containers
# This module provides standard settings for Proxmox LXC containers
# It configure autologin feature to atuin server with one shared user "admin"
# Import this in every LXC container configuration
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    ../system/certificates.nix
    ../system/secrets.nix
    ./users.nix
    ./atuin-login.nix
  ];

  # Default LXC container settings
  options.services.lxc-base = {
    enable =
      lib.mkEnableOption "Base LXC container configuration"
      // {
        default = true;
      };
  };

  config = lib.mkIf config.services.lxc-base.enable {
    # SOPS secrets management with Atuin
    services.secrets = {
      enable = true;
      enableAtuin = true;
    };

    # Automatic Atuin login for shell history sync
    services.atuin-auto-login = {
      enable = true;
      user = "nixadm";
      username = "admin"; # Shared account across all servers
    };

    # Nix settings optimized for LXC
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];

      # Trust nixadm and wheel for remote deployments
      trusted-users = ["nixadm" "root" "@wheel"];

      # Disable sandbox in LXC (kernel namespace limitations)
      sandbox = false;

      # Optimize for remote deployments
      keep-outputs = false;
      keep-derivations = false;
    };

    # Standard networking for home.lan
    networking = {
      domain = "home.lan";
      search = ["home.lan"];
      nameservers = ["192.168.50.1"]; # FreeIPA DNS
      useDHCP = lib.mkDefault true;

      firewall = {
        enable = true;
        allowedTCPPorts = [22]; # SSH only by default
      };
    };

    # DNS resolution via systemd-resolved + FreeIPA
    services.resolved = {
      enable = true;
      dnssec = "false";
      domains = ["home.lan"];
      fallbackDns = ["9.9.9.9"]; # Quad9 fallback
      extraConfig = ''
        [Resolve]
        DNS=192.168.50.1
        Domains=home.lan
        DNSoverTLS=no
      '';
    };

    # Locale and timezone
    time.timeZone = "Europe/Warsaw";
    i18n.defaultLocale = "en_US.UTF-8";

    # Essential server packages
    environment.systemPackages = with pkgs; [
      # Core utilities
      vim
      git
      curl
      wget
      htop
      btop

      # Network diagnostics
      bind # dig, nslookup
      inetutils # ping, telnet

      # Modern replacements
      eza # Better ls
      zoxide # Smart cd
      starship # Customizable prompt

      # Shell history
      atuin
    ];

    # SSH server configuration
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no"; # Already set in users.nix, but explicit here
      };
    };

    # Automatic system maintenance
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Optimize store
    nix.optimise = {
      automatic = true;
      dates = ["weekly"];
    };
  };
}
