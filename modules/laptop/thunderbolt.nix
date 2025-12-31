# Thunderbolt 3 support for docking stations
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable Thunderbolt support
  services.hardware.bolt.enable = true;

  # Add thunderbolt management tool
  environment.systemPackages = with pkgs; [
    bolt # Thunderbolt device management
  ];
}
