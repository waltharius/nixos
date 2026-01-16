# modules/home/desktop/kde/base.nix
# Core KDE packages
{pkgs, ...}: {
  home.packages = with pkgs; [
    # KDE applications
    kate # Text editor
    dolphin # File manager
    konsole # Terminal
    okular # Document viewer
    gwenview # Image viewer
    ark # Archive manager
    spectacle # Screenshot tool

    # KDE utilities
    kdePackages.plasma-systemmonitor
    kdePackages.kio-extras
  ];
}
