# modules/system/desktop-environments/kde.nix
# System-level KDE Plasma desktop environment configuration

{ config, lib, pkgs, ... }:

{
  # Enable X11
  services.xserver.enable = true;
  
  # KDE Plasma 6
  services.desktopManager.plasma6.enable = true;
  
  # SDDM Display Manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  
  # XDG portal for KDE
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-kde ];
  };
}
