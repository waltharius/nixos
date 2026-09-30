# hosts/machines/cloud-apps.nix - fields are described in hosts/README.md
{
  class = "virtual";
  system = "x86_64-linux";
  description = "Proxmox LXC - Nextcloud, MariaDB, Syncthing";
  tags = ["prod" "lxc" "cloud"];
  lan.ip = "192.168.50.8";
  users.nixadm.groups = ["cli"];

  ssh.hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOtkM74WDKsbfk/rezFnEPUHGUnHLueu+adykUDmMLU";

  sops = {
    # Called `servers-shared` in the hand-written .sops.yaml. It stays
    # cloud-apps' own key; no other host may use it.
    ageKey = "age1qu4pnzn2teff7m78nrhzq4vct4qczp2ajhfda559xgpk2n08qswqzyh2aw";
    keySource = "key-file";
  };
}
