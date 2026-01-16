# modules/home/desktop/gnome/base.nix
# Core GNOME packages and basic configuration
{pkgs, ...}: {
  # Core GNOME user packages
  home.packages = with pkgs; [
    gnome-tweaks
    dconf-editor
    nautilus
    gnome-system-monitor
    gnome-screenshot
  ];

  # GTK theme - you like light theme!
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita";
      package = pkgs.gnome-themes-extra;
    };
  };
}
