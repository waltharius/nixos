# hosts/devices/parter-asus.nix - fields are described in hosts/README.md
{
  description = "ASUS Wi-Fi router (parter)";
  lan.ip = "192.168.50.221";
  ssh.parter-asus = {
    user = "horacjusz";
    port = 1024;
  };
  category = "network";
  baremetal = true;
  # Ping only for now: no USB stick, so no Entware and no node_exporter.
  # With a stick: Entware and node_exporter as on office-asus, then
  # `monitoring.nodeExternal = true` (BACKLOG.md, stage 5b step 5).
  monitoring.ping = true;
}
