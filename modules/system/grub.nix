# Adaptive GRUB configuration for multiple hosts
{hostname, ...}: let
  # Define display settings per host
  hostSettings = {
    sukkub = {
      # ThinkPad P50 with 4K display
      resolution = "1920x1080";
      fontSize = 32;
    };

    azazel = {
      # Standard 1080p or lower
      resolution = "1920x1080"; # or "auto" for detection
      fontSize = 24; # Smaller font for lower DPI
    };

    # Default fallback for unknown hosts
    default = {
      resolution = "auto";
      fontSize = 24;
    };
  };

  # Select settings based on current hostname
  currentHost = hostSettings.${hostname} or hostSettings.default;
in {
  boot.loader = {
    grub = {
      # Apply host-specific resolution
      gfxmodeEfi = currentHost.resolution;
      gfxmodeBios = currentHost.resolution;

      # Apply host-specific font size
      fontSize = currentHost.fontSize;

      # These are the same for all hosts
      configurationLimit = 10;

      # Optional: Pretty theme (same for all hosts)
      # theme = pkgs.nixos-grub2-theme;
    };
    timeout = 5;
  };
}
