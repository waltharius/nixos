# Gaming configuration including Steam and performance optimizations
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Enable Steam with all necessary compatibility layers
  programs.steam = {
    enable = true;

    # Enable GameMode for automatic performance optimizations
    gamescopeSession.enable = true;

    # Add extra compatibility tools
    extraCompatPackages = with pkgs; [
      # Community Proton version with additional fixes
      proton-ge-bin
    ];

    # Desktop integration
    remotePlay.openFirewall = true; # Open ports for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source dedicated servers
    localNetworkGameTransfers.openFirewall = true; # For faster downloads from other PCs
  };

  # GameMode - automatic system optimizations when games are running
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10; # Adjust niceness of games
      };

      # GPU optimizations (NVIDIA specific)
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        nv_powermizer_mode = 1; # Maximum performance when gaming
      };
    };
  };

  # Gaming-related packages
  environment.systemPackages = with pkgs; [
    mangohud # FPS counter and performance overlay
    gamemode # Runtime
    gamescope # Micro-compositor for gaming

    # Optional: Additional gaming tools
    # wine # Windows compatibility layer
    # winetricks # Wine helper scripts
    # lutris # Game launcher
    # heroic # Epic Games and GOG launcher
  ];

  # Increase file descriptor limit for games
  # Some games need more open files than the default limit
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "524288";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "1048576";
    }
  ];
}
