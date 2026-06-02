# hosts/workstations/azazel/tlp.nix
#
# TLP power management tuned for ThinkPad T16 Gen3 (azazel).
#
# Differences from the shared baseline:
#   - USB_BLACKLIST targets the Lenovo Thunderbolt 4 dock peripherals
#     (audio adapter 17ef:306a, MCU 17ef:3066, LAN 17ef:3069). These
#     cause udev worker timeouts when TLP tries to autosuspend them.
#   - RUNTIME_PM_DRIVER_BLACKLIST is not needed: azazel has no discrete
#     GPU, so TLP can manage all PCI devices normally.
#
# The shared TLP service hardening (TimeoutStopSec, KillMode) is
# reproduced here because tlp.nix is now host-specific and the common
# module no longer exists.
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

      # Lenovo ThinkPad T16 battery health thresholds.
      START_CHARGE_THRESH_BAT0 = 70;
      STOP_CHARGE_THRESH_BAT0  = 85;

      DISK_IDLE_SECS_ON_AC  = 0;
      DISK_IDLE_SECS_ON_BAT = 2;

      WIFI_PWR_ON_AC  = "off";
      WIFI_PWR_ON_BAT = "on";

      RUNTIME_PM_ON_AC  = "on";
      RUNTIME_PM_ON_BAT = "auto";

      USB_AUTOSUSPEND  = 1;
      USB_EXCLUDE_PHONE = 1;

      # Lenovo Thunderbolt 4 dock peripherals — autosuspend causes udev
      # worker timeouts. Identified via lsusb: audio 17ef:306a,
      # MCU 17ef:3066, LAN 17ef:3069.
      USB_BLACKLIST = "17ef:306a 17ef:3066 17ef:3069";
    };
  };

  # Disable TLP's RDW udev rules — the Thunderbolt dock causes worker
  # timeouts when TLP probes its radio devices on hotplug events.
  environment.etc."udev/rules.d/85-tlp.rules".text =
    "# TLP RDW disabled — Thunderbolt dock causes udev worker timeouts\n";

  systemd.services.tlp.serviceConfig = {
    TimeoutStopSec = "30s";
    KillMode       = "mixed";
    SendSIGKILL    = "yes";
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = false;
}
