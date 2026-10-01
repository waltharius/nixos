# hosts/machines/azazel.nix - fields are described in hosts/README.md
{
  class = "workstation";
  system = "x86_64-linux";
  description = "ThinkPad T16 Gen3 - primary workstation";
  tags = ["workstation" "laptop"];
  # Static address on the home Wi-Fi (modules/system/wifi.nix).
  lan.ip = "192.168.50.80";
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
    "cli"
  ];

  ssh.hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFttowJEDMimtkelgVqqJkmzMRP72PPImaXLF8EKAPIY";

  sops = {
    # Same key as the admin key (hosts/fleet.nix): the admin key lives on
    # azazel anyway, so a separate host key would not protect anything.
    ageKey = "age1t73dnh9pj2qsz3rfqgq54t2pyxh8ew6w8xsta7pfwmmxmsjswgrshue8gx";
    keySource = "key-file";
  };
}
