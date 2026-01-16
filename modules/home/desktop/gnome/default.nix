# modules/home/desktop/gnome/default.nix
# Main GNOME user configuration
{...}: {
  imports = [
    ./base.nix
    ./extensions.nix
    ./dconf.nix
  ];
}
