# hosts/workstations/baal/writing.nix
#
# Frequent snapshots of marcin's writing subvolumes (Documents, notes,
# syncthing), created by ./disko.nix. The snapshot logic and snapper
# configuration are in modules/system/btrfs.nix. Written by
# `nix run .#new-host` for the disk layout btrfs-luks-writing.
{...}: {
  imports = [../../../modules/system/btrfs.nix];

  custom.btrfs = {
    allowUsers = ["marcin"];
    writingSubvolumes = {
      documents = "/home/marcin/Documents";
      notes = "/home/marcin/notes";
      syncthing = "/home/marcin/syncthing";
    };
  };
}
