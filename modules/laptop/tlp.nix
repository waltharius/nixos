# ../modules/laptop/tlp.nix
# TLP power management for laptops
# Optimizes battery life and CPU performance based on AC/battery state
{...}: {
  services.tlp = {
    enable = true;

    settings = {
      # CPU settings
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 30;

      # CPU boost
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # Platform profile (for modern laptops)
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # Battery charge thresholds (prevents battery degradation)
      # Only charge when below START_THRESHOLD, stop at STOP_THRESHOLD
      START_CHARGE_THRESH_BAT0 = 70;
      STOP_CHARGE_THRESH_BAT0 = 85;

      # Disk settings
      DISK_IDLE_SECS_ON_AC = 0;
      DISK_IDLE_SECS_ON_BAT = 2;

      # WiFi power save
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # Runtime PM for PCI(e) devices
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # USB autosuspend
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_PHONE = 1;

      # Blacklist Thunderbolt dosc USB devices
      # By lsusb I know that my dock has these:
      # 17ef:306a (Audio), 17ef:3066 (MCU), 17ef:3069 (LAN)
      USB_BLACKLIST = "17ef:306a 17ef:3066 17ef:3069";
    };
  };

  # Completely disable TLP's RDW by masking its udev rules
  # This is the nuclear option - creates an empty file that overrides TLP's rules
  environment.etc."udev/rules.d/85-tlp.rules" = {
    text = "# TLP RDW disabled - Thunderbolt dock causes udev worker timeouts\n";
  };

  # Disable TLP's systemd-rfkill integration
  # This prevents TLP from trying to manage radio devices on suspend/resume
  # Add timeout protection to TLP service
  systemd.services.tlp = {
    serviceConfig = {
      # Prevent TLP from hanging shutdown
      TimeoutStopSec = "30s";
      # Kill TLP aggressively if it doesn't respond
      KillMode = "mixed";
      SendSIGKILL = "yes";
    };
  };

  # Enable power management daemon
  services.upower.enable = true;

  # Disable conflicting power management services
  services.power-profiles-daemon.enable = false;
}
