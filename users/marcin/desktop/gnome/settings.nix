# users/marcin/desktop/gnome/settings.nix
# Marcin's personal GNOME settings (theme, hot corners, etc.)

{...}: {
  dconf.settings = {
    # ==========================================
    # Interface settings - YOUR preferences
    # ==========================================
    "org/gnome/desktop/interface" = {
      color-scheme = "default"; # LIGHT theme (you love it!)
      clock-show-weekday = true;
      enable-hot-corners = true; # You use hot corners constantly!
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
