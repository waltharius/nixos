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
# To unlock remotely after reboot:
#
#   ssh -p 2222 root@192.168.50.150
#   systemctl default
#
# systemctl default responds to the pending systemd-ask-password request
# raised by systemd-cryptsetup and causes the passphrase prompt to appear
# in the SSH session. This is the correct mechanism under systemd initrd;
# cryptsetup-askpass only exists in the legacy (non-systemd) initrd.
#
# Recommended ~/.ssh/config entry on the client to avoid known_hosts
# conflicts (the initrd host key differs from the normal sshd key):
#
#   Host altair-initrd
#     HostName 192.168.50.150
#     Port 2222
#     User root
#     UserKnownHostsFile ~/.ssh/known_hosts_initrd
#     StrictHostKeyChecking accept-new
#
{pkgs, ...}: {
  # ---------------------------------------------------------------------------
  # Network — two stacks run in parallel in the initrd:
  #
  # 1. boot.initrd.systemd.network (systemd-networkd) — required for
  #    systemd-cryptsetup and other stage-1 systemd units that depend on
  #    network-online.target.
  #
  # 2. boot.initrd.network (legacy stack) — required to activate
  #    boot.initrd.network.ssh. Even with boot.initrd.systemd.enable = true
  #    the legacy SSH daemon still starts correctly when this is enabled;
  #    only the legacy *network* setup scripts are redundant (networkd wins).
  #
  # Both stacks coexist without conflict: networkd manages the interface,
  # the legacy stack only contributes the SSH daemon.
  #
  # Matching by MAC address in the networkd config: udev predictable naming
  # rules are not yet applied inside the initrd environment so the interface
  # name seen here may differ from the fully-booted system. The MAC address
  # is stable and unambiguous.
  # NIC: Intel I226-V 2.5G — MAC 30:c5:99:5b:ec:97
  # ---------------------------------------------------------------------------
  boot.initrd.network.enable = true;

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
  # SSH daemon
  #
  # boot.initrd.network.ssh works correctly alongside boot.initrd.systemd.enable.
  # There is no boot.initrd.systemd.ssh option in NixOS; the legacy SSH module
  # is the supported path for initrd SSH regardless of whether systemd stage-1
  # is active.
  #
  # Root shell is left at the default (/bin/sh). After connecting, run:
  #   systemctl default
  # to forward the pending LUKS passphrase prompt to the SSH session.
  # ---------------------------------------------------------------------------
  boot.initrd.network.ssh = {
    enable = true;
    port = 2222;
    hostKeys = ["/etc/secrets/initrd/ssh_host_ed25519_key"];
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDNK9DIORkZzPOOya7WW3LpeaYYMCTtfC33/uz9fLupV JuiceSSH"
    ];
  };

  # ---------------------------------------------------------------------------
  # Host key — embedded into the initrd at build time.
  #
  # The key on the left is the path inside the initrd image.
  # The value on the right is where nixos-rebuild reads it from on the host.
  # Both point to the same location because /etc/secrets lives on the
  # encrypted root and must be baked in before the first boot.
  # ---------------------------------------------------------------------------
  boot.initrd.secrets = {
    "/etc/secrets/initrd/ssh_host_ed25519_key" = "/etc/secrets/initrd/ssh_host_ed25519_key";
  };

  networking.firewall.allowedTCPPorts = [2222];
}
