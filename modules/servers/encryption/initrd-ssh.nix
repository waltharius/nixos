# modules/servers/encryption/initrd-ssh.nix
# Minimal initrd SSH for remote LUKS unlock over LAN (port 2222)
{pkgs, ...}: {
  # Systemd-networkd in initrd (required when boot.initrd.systemd.enable = true)
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

  #     With systemd initrd, use boot.initrd.systemd.users/ssh instead of
  #     boot.initrd.network.ssh — the legacy stack is dead when systemd is on.
  boot.initrd.network.ssh = {
    enable = true; # Still needed to register the SSH binary in initrd
    port = 2222;
    hostKeys = ["/etc/secrets/initrd/ssh_host_ed25519_key"];
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
    ];
  };

  #     CRITICAL: copy the host key INTO the initrd image at build time.
  #     Without this, the key file doesn't exist when initrd runs (root FS
  #     is still locked). Generate once with:
  #       sudo mkdir -p /etc/secrets/initrd
  #       sudo ssh-keygen -t ed25519 -N "" -f /etc/secrets/initrd/ssh_host_ed25519_key
  #       sudo chmod 600 /etc/secrets/initrd/ssh_host_ed25519_key
  boot.initrd.secrets = {
    "/etc/secrets/initrd/ssh_host_ed25519_key" = "/etc/secrets/initrd/ssh_host_ed25519_key";
  };

  networking.firewall.allowedTCPPorts = [2222];
}
