# hosts/machines/azazel.nix - fields are described in hosts/README.md
{
  class = "workstation";
  system = "x86_64-linux";
  description = "ThinkPad T16 Gen3 - primary workstation";
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
}
