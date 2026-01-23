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

  # Systemd sleep configuration
  systemd.sleep.extraConfig = ''
    # Hibernate after X hours of suspend
    HibernateDelaySec=2min

    # Use 'mem' suspend state (suspend-to-RAM)
    SuspendState=mem
  '';

  services.logind.extraConfig = ''
    # On battery: suspend-then-hibernate
    HandleLidSwitch=suspend-then-hibernate
    HandleLidSwitchDocked=suspend-then-hibernate

    # On AC power: ONLY suspend, NEVER hibernate
    HandleLidSwitchExternalPower=suspend

    HandlePowerKey=suspend-then-hibernate
    IdleAction=suspend-then-hibernate
    IdleActionSec=30min
    KillUserProcesses=no
    LidSwitchIgnoreInhibited=yes
  '';

  # Enable hibernate target
  systemd.targets = {
    hibernate.enable = true;
    suspend-then-hibernate.enable = true;
  };
}
