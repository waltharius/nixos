# hosts/devices/office-asus.nix - fields are described in hosts/README.md
{
  description = "ASUS Wi-Fi router (office)";
  lan.ip = "192.168.50.220";
  ssh.office-asus = {
    user = "horacjusz";
    port = 1024;
  };
  category = "network";
  baremetal = true;
  monitoring = {
    ping = true;
    # node_exporter from Entware on the USB stick, started by
    # /jffs/scripts/post-mount (/opt/etc/init.d/S99node_exporter); not
    # installed by `nix run .#fleet`.
    nodeExternal = true;
  };
}
