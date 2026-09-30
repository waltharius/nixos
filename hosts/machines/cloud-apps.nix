# hosts/machines/cloud-apps.nix - fields are described in hosts/README.md
{
  class = "virtual";
  system = "x86_64-linux";
  description = "Proxmox LXC - Nextcloud, MariaDB, Syncthing";
  tags = ["prod" "lxc" "cloud"];
  lan.ip = "192.168.50.8";
  users.nixadm.groups = ["cli"];
}
