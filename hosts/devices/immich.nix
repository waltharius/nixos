# hosts/devices/immich.nix - fields are described in hosts/README.md
{
  description = "Immich (Proxmox guest)";
  lan.ip = "192.168.50.100";
  ssh.immich.user = "root";
  monitoring.ping = true;
}
