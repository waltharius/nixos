# modules/servers/encryption/initrd-ssh.nix
# Minimal initrd SSH for remote LUKS unlock over LAN (port 2222)
{...}: {
  # Static IP in initrd so SSH is reachable before LUKS unlock
  boot.initrd.systemd.network = {
    enable = true;
    networks."10-initrd-lan" = {
      matchConfig.Name = "enp10s0";
      networkConfig = {
        Address = "192.168.50.150/24";
        Gateway = "192.168.50.1";
        DHCP = "no";
        IPv6AcceptRA = false;
      };
    };
  };

  # initrd SSH daemon on port 2222
  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      # Key exists at this path — generated during install
      hostKeys = ["/etc/secrets/initrd/ssh_host_ed25519_key"];
      # Same key you use for normal SSH
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDAjotcnH5sc53LpSkSLs7XNx0"
      ];
    };
  };

  # Open port 2222 in firewall (needed post-boot too so nixos-rebuild doesn't drop it)
  networking.firewall.allowedTCPPorts = [2222];
}
