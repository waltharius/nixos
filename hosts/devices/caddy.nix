# hosts/devices/caddy.nix - fields are described in hosts/README.md
{
  description = "Caddy reverse proxy (Debian, to be moved to NixOS)";
  lan.ip = "192.168.50.114";
  ssh.caddy.user = "root";
  monitoring.ping = true;
}
