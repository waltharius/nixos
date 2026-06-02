# hosts/workstations/sukkub/hibernate.nix
#
# Suspend and hibernate configuration for ThinkPad P50 (sukkub).
#
# Sleep policy: suspend-then-hibernate.
# Same policy as azazel; delay is shorter because sukkub is a test/POC
# machine that is less likely to stay suspended for many hours.
#
# Swap size: 16 GB.
# sukkub has 32 GB RAM with typical usage well under 16 GB.
# If RAM usage ever approaches 16 GB, increase this value and re-run
# mkswap on the swap file before the next hibernate.
{ ... }: {
  swapDevices = [{
    device = "/swap/swapfile";
    size   = 16 * 1024; # 16 GB in MiB
  }];

  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "4h";
    SuspendState      = "mem";
  };

  services.logind.settings.Login = {
    HandleLidSwitch              = "suspend";
    HandleLidSwitchDocked        = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey               = "suspend";
    LidSwitchIgnoreInhibited = "yes";
    InhibitDelayMaxSec       = "30s";
  };

  systemd.targets = {
    hibernate.enable              = true;
    suspend-then-hibernate.enable = true;
  };

  boot.kernelParams = [];
}
