# hosts/machines/sukkub.nix - fields are described in hosts/README.md
{
  class = "workstation";
  system = "x86_64-linux";
  description = "ThinkPad P50 - test/POC workstation";
  tags = ["workstation" "laptop"];
  # Static address on the home Wi-Fi (modules/system/wifi.nix).
  lan.ip = "192.168.50.81";
  users.marcin.groups = [
    "gnome"
    "emacs"
    "office"
    "latex"
    "web"
    "comms"
    "media"
    "gaming"
    "nix-admin"
    "nix-local"
    "syncthing"
    "cli"
  ];

  # Tailscale (lib/tailscale.nix, docs/REMOTE-ACCESS.md): marcin's own
  # laptop; the home LAN route of the pfSense subnet router when away.
  tailscale = {
    join = "owner";
    acceptRoutes = true;
  };

  ssh.hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG7lgvMgxcyiT9UNSjj3arWi5AXINsekHoTQnscTrmDa";

  sops = {
    ageKey = "age1lrla3ltkfljhshrlp2cqr3mzm3hvyxmka6fjs68ck2ykwgnjygwql9twy2";
    keySource = "key-file";
  };
}
