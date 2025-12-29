# Network configuration
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable NetworkManager for easy network management
  networking.networkmanager.enable = true;

  # Enable firewall
  networking.firewall = {
    enable = true;
    # Allow Syncthing ports
    allowedTCPPorts = [22 8384 22000];
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPorts = [22000 21027];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
  };

  # Enable OpenSSH daemon
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };
}
