# modules/servers/encryption/initrd-ssh.nix
#
# Remote LUKS unlock over SSH during early boot (initrd stage).
# Port 2222 is used to keep the initrd listener separate from the
# normal sshd on port 22 that starts after the root FS is mounted.
#
# Prerequisites — run once on the host before the first nixos-rebuild:
#
#   sudo mkdir -p /etc/secrets/initrd
#   sudo ssh-keygen -t ed25519 -N "" -f /etc/secrets/initrd/ssh_host_ed25519_key
#   sudo chmod 600 /etc/secrets/initrd/ssh_host_ed25519_key
#   sudo chmod 700 /etc/secrets/initrd
#
# The key is embedded into the initrd image at build time (see
# boot.initrd.secrets below) because the root filesystem is still
# encrypted when the initrd runs and cannot be read from disk.
#
# To unlock remotely after boot:
#
#   ssh -p 2222 root@<host-ip>
#   systemd-tty-ask-password-agent --query
#
# Recommended ~/.ssh/config entry on the client to avoid known_hosts
# conflicts (the initrd host key differs from the normal sshd key):
#
#   Host <hostname>-initrd
#     HostName <host-ip>
#     Port 2222
#     User root
#     UserKnownHostsFile ~/.ssh/known_hosts_initrd
#     StrictHostKeyChecking accept-new
#
{pkgs, ...}: {
  # ---------------------------------------------------------------------------
  # Network — systemd-networkd inside initrd
  #
  # boot.initrd.systemd.enable = true activates a minimal systemd instance
  # in the initrd. Network must be configured through its own networkd, not
  # through the host-level systemd.network or boot.initrd.network options.
  #
  # Matching by MAC address rather than interface name: udev predictable
  # network naming rules are not yet applied in the initrd environment, so
  # the interface name seen here may differ from the fully-booted system.
  # The MAC address is stable and unambiguous.
  # NIC: Intel I226-V 2.5G — MAC 30:c5:99:5b:ec:97
  # ---------------------------------------------------------------------------
  boot.initrd.systemd.network = {
    enable = true;
    networks."10-initrd-lan" = {
      matchConfig.MACAddress = "30:c5:99:5b:ec:97";
      networkConfig = {
        Address = "192.168.50.150/24";
        Gateway = "192.168.50.1";
        DHCP = "no";
        IPv6AcceptRA = false;
      };
    };
  };

  # ---------------------------------------------------------------------------
  # SSH — systemd-initrd native SSH daemon
  #
  # boot.initrd.network.ssh belongs to the legacy (non-systemd) initrd network
  # stack and is inactive when boot.initrd.systemd.enable = true. The correct
  # option under systemd initrd is boot.initrd.systemd.ssh.
  #
  # The root shell is set to systemd-tty-ask-password-agent so that
  # connecting over SSH immediately forwards any pending password prompts
  # (including the LUKS passphrase) to the terminal.
  # ---------------------------------------------------------------------------
  boot.initrd.systemd.users.root.shell = "/bin/systemd-tty-ask-password-agent";

  boot.initrd.systemd.ssh = {
    enable = true;
    port = 2222;
    hostKeys = ["/etc/secrets/initrd/ssh_host_ed25519_key"];
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
    ];
  };

  # ---------------------------------------------------------------------------
  # Host key — embedded into the initrd at build time
  #
  # The source path on the left is the destination path inside the initrd.
  # The value on the right is where nixos-rebuild reads it from on the host.
  # Both point to the same location because the key lives in /etc/secrets
  # which is on the encrypted root — it must be baked in before first boot.
  # ---------------------------------------------------------------------------
  boot.initrd.secrets = {
    "/etc/secrets/initrd/ssh_host_ed25519_key" = "/etc/secrets/initrd/ssh_host_ed25519_key";
  };

  networking.firewall.allowedTCPPorts = [2222];
}
