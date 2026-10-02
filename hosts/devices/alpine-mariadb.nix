# hosts/devices/alpine-mariadb.nix - fields are described in hosts/README.md
{
  description = "MariaDB (Alpine, Proxmox guest)";
  lan.ip = "192.168.50.152";
  ssh.alpine-mariadb.user = "root";
  monitoring.ping = true;
}
