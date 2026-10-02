# hosts/devices/office-asus.nix - fields are described in hosts/README.md
{
  description = "ASUS Wi-Fi router (office)";
  lan.ip = "192.168.50.220";
  ssh.office-asus = {
    user = "horacjusz";
    port = 1024;
  };
  monitoring.ping = true;
}
