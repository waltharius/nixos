# hosts/workstations/sukkub/tlp.nix
#
# TLP power management tuned for ThinkPad P50 (sukkub).
#
# Differences from azazel:
#   - RUNTIME_PM_DRIVER_BLACKLIST excludes the NVIDIA and nouveau drivers
#     from TLP runtime power management. The NVIDIA driver manages its own
#     power state; letting TLP touch the GPU causes conflicts and can
#     prevent resume from suspend.
#   - No USB_BLACKLIST: sukkub uses a different dock without the Lenovo
#     peripherals that cause udev worker timeouts on azazel.
#   - Battery thresholds are identical — both are ThinkPad batteries with
#     Lenovo's charge control interface.
{ ... }: {
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC  = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC  = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_MIN_PERF_ON_AC  = 0;
      CPU_MAX_PERF_ON_AC  = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 30;

      CPU_BOOST_ON_AC  = 1;
      CPU_BOOST_ON_BAT = 0;

      PLATFORM_PROFILE_ON_AC  = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      START_CHARGE_THRESH_BAT0 = 70;
      STOP_CHARGE_THRESH_BAT0  = 85;

      DISK_IDLE_SECS_ON_AC  = 0;
      DISK_IDLE_SECS_ON_BAT = 2;

      WIFI_PWR_ON_AC  = "off";
      WIFI_PWR_ON_BAT = "on";

      RUNTIME_PM_ON_AC  = "on";
      RUNTIME_PM_ON_BAT = "auto";

      USB_AUTOSUSPEND   = 1;
      USB_EXCLUDE_PHONE = 1;

      # Prevent TLP from managing the NVIDIA GPU runtime power state.
      # The proprietary NVIDIA driver handles its own power management;
      # TLP interference causes resume failures after suspend.
      RUNTIME_PM_DRIVER_BLACKLIST = "nvidia nouveau";
    };
  };

  systemd.services.tlp.serviceConfig = {
    TimeoutStopSec = "30s";
    KillMode       = "mixed";
    SendSIGKILL    = "yes";
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = false;
}
