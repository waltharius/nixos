# hosts/machines/altair.nix - fields are described in hosts/README.md
{
  class = "server";
  system = "x86_64-linux";
  description = "ASUS ProArt X870E, Ryzen 9 7900, 64 GB DDR5, 2x RTX 3090";
  tags = ["server" "baremetal" "gpu" "llm"];
  lan.ip = "192.168.50.150";
  users.nixadm.groups = ["cli"];

  sops = {
    ageKey = "age1j73et2st2j8njdn06fsx38e5cgf3z0x00decgjuz3ldhklyk9azsqs9ggj";
    keySource = "key-file";
  };
}
