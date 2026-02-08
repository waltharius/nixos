# modules/servers/roles/raspberry-pi-hardware.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.hardware.raspberry-pi-optimizations;
in {
  options.hardware.raspberry-pi-optimizations = {
    enable = mkEnableOption "Raspberry Pi hardware optimizations";

    enableZRAM = mkOption {
      type = types.bool;
      default = true;
      description = "Enable ZRAM for compressed swap in RAM";
    };

    zramSize = mkOption {
      type = types.int;
      default = 50;
      description = "ZRAM size as percentage of RAM";
    };

    enableTempMonitoring = mkOption {
      type = types.bool;
      default = true;
      description = "Enable temperature monitoring logs";
    };
  };

  config = mkIf cfg.enable {
    # ZRAM for better memory management
    zramSwap = mkIf cfg.enableZRAM {
      enable = true;
      memoryPercent = cfg.zramSize;
    };

    # SD card optimizations
    fileSystems."/" = {
      options = ["noatime" "nodiratime"];
    };

    # Reduce journald logging to SD card
    services.journald.extraConfig = ''
      SystemMaxUse=100M
      SystemMaxFileSize=10M
      RuntimeMaxUse=50M
    '';

    # Temperature monitoring script
    systemd.services.rpi-temp-monitor = mkIf cfg.enableTempMonitoring {
      description = "Log RPi temperature";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"RPi Temp: $(${pkgs.libraspberrypi}/bin/vcgencmd measure_temp)\" | ${pkgs.systemd}/bin/systemd-cat -t rpi-temp'";
      };
    };

    systemd.timers.rpi-temp-monitor = mkIf cfg.enableTempMonitoring {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "30m";
      };
    };

    # Essential RPi packages
    environment.systemPackages = with pkgs; [
      libraspberrypi # RPi tools (vcgencmd, etc.)
      raspberrypi-eeprom # Firmware updates
    ];

    # Enable firmware
    hardware.enableRedistributableFirmware = true;
  };
}
