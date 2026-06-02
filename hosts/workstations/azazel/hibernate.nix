# hosts/workstations/azazel/hibernate.nix
#
# Suspend and hibernate configuration for ThinkPad T16 Gen3 (azazel).
#
# Sleep policy: suspend-then-hibernate.
# The machine suspends to RAM immediately on lid close, then hibernates
# to disk after HibernateDelaySec. This preserves fast resume while
# ensuring the session survives a full battery drain.
#
# Swap size: 45 GB.
# azazel has 128 GB RAM. Peak observed usage is ~25 GB; 45 GB gives a
# safe margin for hibernation while keeping the swap partition reasonable.
{ ... }: {
  swapDevices = [{
    device = "/swap/swapfile";
    size   = 45 * 1024; # 45 GB in MiB
  }];

  # systemd.sleep.extraConfig was removed in NixOS 26.05.
  # systemd.sleep.settings maps directly to sleep.conf.d/*.conf sections.
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "8h";
    SuspendState      = "mem";
  };

  services.logind.settings.Login = {
    # Suspend on lid close regardless of docked state.
    HandleLidSwitch              = "suspend";
    HandleLidSwitchDocked        = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey               = "suspend";
    # Do not let applications block suspend on a laptop.
    LidSwitchIgnoreInhibited = "yes";
    InhibitDelayMaxSec       = "30s";
  };

  systemd.targets = {
    hibernate.enable             = true;
    suspend-then-hibernate.enable = true;
  };

  boot.kernelParams = [];
}
