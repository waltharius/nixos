# Suspend-then-hibernate configuration
# System suspends to RAM, then automatically hibernates to disk after delay
# This saves battery while maintaining fast resume from suspend
{
  config,
  lib,
  pkgs,
  hostname,
  ...
}: {
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

  # Enable resume from hibernation
  boot.resumeDevice = "/dev/disk/by-uuid/REPLACE-WITH-ROOT-UUID";

  # Systemd sleep configuration
  systemd.sleep.extraConfig = ''
    # Hibernate after 3 hours of suspend
    HibernateDelaySec=3h

    # Use 'mem' suspend state (suspend-to-RAM)
    SuspendState=mem
  '';

  # Logind configuration for lid and power button
  services.logind = {
    # Suspend-then-hibernate when lid is closed
    lidSwitch = "suspend-then-hibernate";

    # On AC power, only suspend (no hibernate needed)
    lidSwitchExternalPower = "suspend";

    settings = {
      Login = {
        HandlePowerKey = "suspend-then-hibernate";
        IdleAction = "suspend-then-hibernate";
        IdleActionSec = "30min";
      };
    };
  };

  # Kernel parameters for better hibernate support
  boot.kernelParams = [
    # Resume from swap
    "resume_offset=0" # Will be calculated automatically by NixOS
  ];

  # Enable hibernate target
  systemd.targets = {
    hibernate.enable = true;
    suspend-then-hibernate.enable = true;
  };
}
