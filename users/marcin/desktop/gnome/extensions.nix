# users/marcin/desktop/gnome/extensions.nix
# Marcin's GNOME extensions configuration
#
# NOTE: This file defines GNOME extensions.
# NOTE: Keyboard shortcuts that depend on these extensions are in shortcuts.nix
# NOTE: Autostart configs that depend on packages are in autostart.nix
{
  pkgs,
  customPkgs ? {},
  ...
}: {
  # Define extension list (used by base extensions module)
  programs.gnome-extensions.extensionPackages = with pkgs.gnomeExtensions; [
    appindicator
    run-or-raise # ← shortcuts.nix depends on this!
    gsconnect
    just-perfection
    power-tracker
    screen-brightness-governor
    shu-zhi
    window-is-ready-remover
    focused-window-d-bus
    customPkgs.solaar-extension
  ];
}
