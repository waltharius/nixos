# hosts/devices/walthpi.nix - fields are described in hosts/README.md
{
  description = "Raspberry Pi";
  lan.ip = "192.168.50.47";
  ssh.walthpi.user = "walthpi";
  monitoring.ping = true;
}
