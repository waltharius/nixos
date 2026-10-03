# hosts/devices/alpine-mariadb.nix - fields are described in hosts/README.md
{
  description = "MariaDB (Alpine, Proxmox guest)";
  lan.ip = "192.168.50.152";
  ssh.alpine-mariadb.user = "root";
  category = "proxmox-guest";
  # Ping only: the Ansible roles support systemd distributions, not Alpine
  # (OpenRC); the guest goes away in the migration to NixOS.
  monitoring.ping = true;
}
