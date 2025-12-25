# Syncthing configuration - Home Manager module
# Minimalist setup: service only, devices/folders managed via GUI
{ config, lib, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    
    # Web GUI on localhost only (secure)
    # For remote access: ssh -L 8384:localhost:8384 user@host
    guiAddress = "127.0.0.1:8384";
    
    # GUI controls devices and folders (not declarative)
    overrideDevices = false;
    overrideFolders = false;
    
    settings = {
      options = {
        # Device discovery
        localAnnounceEnabled = true;
        globalAnnounceEnabled = true;
        
        # Relay and NAT traversal
        relaysEnabled = true;
        natEnabled = true;
        stunKeepaliveStartS = 180;
        stunKeepaliveMinS = 20;
        
        # Bandwidth (unlimited)
        limitBandwidthInLan = false;
        maxSendKbps = 0;
        maxRecvKbps = 0;
        
        # Performance
        maxFolderConcurrency = 0;  # auto
        
        # Privacy
        urAccepted = -1;  # no telemetry
        
        # Updates managed by Nix
        autoUpgradeIntervalH = 0;
        
        # Database
        databaseTuning = "auto";
        
        # Disk space warning at 1%
        minHomeDiskFree = {
          value = 1;
          unit = "%";
        };
      };
    };
  };
}
