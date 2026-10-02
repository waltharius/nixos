# hosts/devices/cloudflare-ddns.nix - fields are described in hosts/README.md
{
  description = "Cloudflare DDNS (Proxmox guest)";
  lan.ip = "192.168.50.10";
  ssh.cloudflare-ddns.user = "root";
  monitoring.ping = true;
}
