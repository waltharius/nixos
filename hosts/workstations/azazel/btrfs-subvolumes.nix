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

  # Dedicated btrfs subvolumes where Snapper stores snapshots.
  # They must stay outside the source subvolume so snapshots never
  # contain their own snapshot storage recursively.
  fileSystems."/home/marcin/Documents/.snapshots" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = mountOpts ++ ["subvol=@home/marcin/Documents/.snapshots"];
  };

  fileSystems."/home/marcin/notes/.snapshots" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = mountOpts ++ ["subvol=@home/marcin/notes/.snapshots"];
  };

  fileSystems."/home/marcin/syncthing/.snapshots" = {
    device = btrfsDevice;
    fsType = "btrfs";
    options = mountOpts ++ ["subvol=@home/marcin/syncthing/.snapshots"];
  };

  custom.btrfs = {
    allowUsers = ["marcin"];
    writingSubvolumes = {
      documents = "/home/marcin/Documents";
      notes = "/home/marcin/notes";
      syncthing = "/home/marcin/syncthing";
    };
  };
}
