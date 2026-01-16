# users/marcin/desktop/gnome/default.nix
# Marcin's complete GNOME configuration

{...}: {
  imports = [
    ./extensions.nix # GNOME extensions list
    ./shortcuts.nix # Keyboard shortcuts (depends on extensions)
    ./autostart.nix # Autostart applications (depends on apps.nix)
    ./settings.nix # Personal GNOME settings (theme, hot corners, etc.)
    ./solaar.nix # Logitech device configuration
  ];
}
