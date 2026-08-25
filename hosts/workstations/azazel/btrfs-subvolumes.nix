# hosts/workstations/azazel/btrfs-subvolumes.nix
#
# Dedicated btrfs subvolumes for frequently-changing, high-value data.
# nofail: prevents boot from dropping into emergency mode if one of these
# specific mounts fails — the system should still boot to a usable state.
{
  config,
  lib,
  pkgs,
  ...
}: let
  btrfsDevice = "/dev/disk/by-uuid/569b4de6-df68-4287-80c0-824dcb3c1e84";
  mountOpts = ["compress=zstd" "noatime" "nofail" "x-systemd.requires=home.mount"];
in {
  fileSystems."/home/marcin/Documents" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = mountOpts ++ ["subvol=@home/marcin/Documents"];
  };

  fileSystems."/home/marcin/notes" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = mountOpts ++ ["subvol=@home/marcin/notes"];
  };

  fileSystems."/home/marcin/syncthing" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = mountOpts ++ ["subvol=@home/marcin/syncthing"];
  };
}
