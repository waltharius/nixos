# hosts/devices/pve.nix - fields are described in hosts/README.md
{
  description = "Proxmox VE host";
  lan.ip = "192.168.50.200";
  ssh.pve.user = "root";
  monitoring.ping = true;
}
