# hosts/devices/ipa.nix - fields are described in hosts/README.md
{
  description = "FreeIPA (Proxmox guest)";
  lan.ip = "192.168.50.250";
  ssh.ipa.user = "root";
  monitoring.ping = true;
}
