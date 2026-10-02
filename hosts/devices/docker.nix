# hosts/devices/docker.nix - fields are described in hosts/README.md
{
  description = "Docker host (Proxmox guest)";
  lan.ip = "192.168.50.9";
  ssh.docker.user = "root";
  monitoring.ping = true;
}
