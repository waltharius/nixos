# modules/laptop/hiberante.nix
# Suspend-then-hibernate configuration
# System suspends to RAM, then automatically hibernates to disk after delay
# This saves battery while maintaining fast resume from suspend
{hostname, ...}: {
  # Swap configuration for hibernation
  # Swap size should be larger than maximum expected RAM usage
  # For 128GB RAM with ~25GB typical usage: 45GB provides safe margin
  swapDevices = [
    {
      device = "/swap/swapfile";
      size =
        if hostname == "azazel"
        then (45 * 1024)
        else (16 * 1024);
      # azazel: 45GB swap (128GB RAM, typically uses 25GB)
      # sukkub: 16GB swap (sufficient for standard usage)
    }
  ];

  # Systemd sleep configuration
  systemd.sleep.extraConfig = ''
    # Hibernate after X hours of suspend
    HibernateDelaySec=1min

    # Use 'mem' suspend state (suspend-to-RAM)
    SuspendState=mem
  '';

  # Logind configuration for lid and power button
  services.logind = {
    settings = {
      Login = {
        # This should make suspend the laptop even when external monitors plugged in
        HandleLidSwitchDocked = "suspend";

        HandlePowerKey = "suspend-then-hibernate";

        # On AC power, only suspend (no hibernate needed)
        HandleLidSwitchExternalPower = "suspend";

        # Suspend-then-hibernate when lid is closed
        HandleLidSwitch = "suspend-then-hibernate";

        # Ignore applications trying to block suspend (good on laptops)
        LidSwitchIgnoreInhibited = "yes";

        InhibitDelayMaxSec = "30s";
      };
    };
  };

  # Enable hibernate target
  systemd.targets = {
    hibernate.enable = true;
    suspend-then-hibernate.enable = true;
  };

  # Disable Thunderbolt devices during hibernate
  # This prevents power state corruption on resume
  boot.kernelParams = [
    # Exclude Thunderbolt from runtime PM during hibernate
    #    "thunderbolt.dyndbg=+p" # Enable Thunderbolt debugging
    "thunderbolt.host_reset=0" # Prevent host controller to reset during boot
  ];
}
