# hosts/workstations/baal/hibernate.nix
#
# Suspend, then hibernate into the swap file disko created
# (/.swapvol/swapfile, 8 GiB, subvolume @swap inside the LUKS volume).
# The initrd unlocks the disk first, then resumes from the swap file.
{...}: {
  boot.resumeDevice = "/dev/mapper/cryptroot";

  # Physical offset of the swap file on the btrfs volume:
  #   sudo btrfs inspect-internal map-swapfile -r /.swapvol/swapfile
  # It changes only when the swap file is recreated; update it then.
  boot.kernelParams = ["resume_offset=533760"];

  # Closing the lid suspends; after 4 hours asleep the laptop hibernates,
  # so a forgotten Wyse does not drain its battery.
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "4h";
    SuspendState = "mem";
  };
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };
}
