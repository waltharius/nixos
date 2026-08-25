# hosts/workstations/azazel/btrfs-subvolumes.nix
#
# Dedicated btrfs subvolumes for frequently-changing, high-value data
# (writing, notes, synced files). Splitting these out from the main
# @home subvolume lets us apply a much more aggressive snapshot policy
# to just these paths, without paying that cost across all of /home.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Same physical btrfs filesystem as / and /home — only the subvol= differs.
  btrfsDevice = "/dev/disk/by-uuid/569b4de6-df68-4287-80c0-824dcb3c1e84";
  mountOpts = ["compress=zstd" "noatime"];
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

  fileSystems."/home/marcin/Sync" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = mountOpts ++ ["subvol=@home/marcin/Sync"];
  };
}
