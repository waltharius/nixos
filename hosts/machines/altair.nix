# hosts/machines/altair.nix - fields are described in hosts/README.md
{
  class = "server";
  system = "x86_64-linux";
  description = "ASUS ProArt X870E, Ryzen 9 7900, 64 GB DDR5, 2x RTX 3090";
  tags = ["server" "baremetal" "gpu" "llm"];
  lan.ip = "192.168.50.150";
  users.nixadm.groups = ["cli"];
}
