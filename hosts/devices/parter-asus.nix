# hosts/devices/parter-asus.nix - fields are described in hosts/README.md
{
  description = "ASUS Wi-Fi router (parter)";
  lan.ip = "192.168.50.221";
  ssh.parter-asus = {
    user = "horacjusz";
    port = 1024;
  };
  monitoring.ping = true;
}
