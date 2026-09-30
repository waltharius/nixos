# hosts/machines/sukkub.nix - fields are described in hosts/README.md
{
  class = "workstation";
  system = "x86_64-linux";
  description = "ThinkPad P50 - test/POC workstation";
  tags = ["workstation" "laptop"];
  users.marcin.groups = [
    "gnome"
    "emacs"
    "office"
    "latex"
    "notes"
    "web"
    "comms"
    "media"
    "gaming"
    "nix-admin"
    "cli"
  ];

  sops = {
    ageKey = "age1lrla3ltkfljhshrlp2cqr3mzm3hvyxmka6fjs68ck2ykwgnjygwql9twy2";
    keySource = "key-file";
  };
}
