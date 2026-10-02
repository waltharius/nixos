# hosts/devices/bedroom-asus.nix - fields are described in hosts/README.md
{
  description = "ASUS Wi-Fi router (bedroom)";
  lan.ip = "192.168.50.219";
  ssh.bedroom-asus = {
    user = "horacjusz";
    port = 1024;
  };
  monitoring.ping = true;
}
