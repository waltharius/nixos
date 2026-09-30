# hosts/machines/altair.nix - fields are described in hosts/README.md
{
  class = "server";
  system = "x86_64-linux";
  description = "ASUS ProArt X870E, Ryzen 9 7900, 64 GB DDR5, 2x RTX 3090";
  tags = ["server" "baremetal" "gpu" "llm"];
  lan = {
    ip = "192.168.50.150";
    # Static address is set on this interface (modules/servers/base-baremetal.nix).
    interface = "enp10s0";
  };
  users.nixadm.groups = ["cli"];

  ssh = {
    # Public SSH host key (`cat /etc/ssh/ssh_host_ed25519_key.pub`); pins
    # altair in /etc/ssh/ssh_known_hosts of every host once filled in.
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA+RMIzozB5siebLy4n4INuJgBWqaIPXyVCzhxc1Qu5d";

    # SSH in the initrd, to enter the LUKS passphrase after a reboot
    # (modules/servers/encryption/initrd-ssh.nix). The initrd has its own
    # host key; add it as `hostKey` here to pin it too.
    aliases.initrd-altair = {
      user = "root";
      port = 2222;
    };
  };

  sops = {
    ageKey = "age1j73et2st2j8njdn06fsx38e5cgf3z0x00decgjuz3ldhklyk9azsqs9ggj";
    keySource = "key-file";
  };
}
