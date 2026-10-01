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

  # disko creates the subvolumes as root; their roots must belong to marcin.
  # tmpfiles `d` also fixes owner and mode of existing directories.
  systemd.tmpfiles.rules = [
    "d /home/marcin/Documents 0700 marcin users -"
    "d /home/marcin/notes 0700 marcin users -"
    "d /home/marcin/syncthing 0700 marcin users -"
  ];
}
