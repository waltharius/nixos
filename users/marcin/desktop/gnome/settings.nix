# users/marcin/desktop/gnome/settings.nix
# Marcin's personal GNOME settings (theme, hot corners, etc.)
{...}: {
  dconf.settings = {
    # ==========================================
    # Interface settings - YOUR preferences
    # ==========================================
    "org/gnome/desktop/interface" = {
      color-scheme = "default";
      clock-show-weekday = true;
      enable-hot-corners = true;
    };

    # ==========================================
    # Touchpad settings
    # ==========================================
    "org/gnome/desktop/peripherals/touchpad" = {
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
    };
  };
}
