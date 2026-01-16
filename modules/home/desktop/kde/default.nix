# modules/home/desktop/kde/default.nix
# Main KDE Plasma configuration

{...}: {
  imports = [
    ./base.nix
    ./plasma.nix
  ];
}
