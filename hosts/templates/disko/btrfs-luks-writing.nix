# Disk layout of @HOST@ (disko), from hosts/templates/disko/btrfs-luks-writing.nix.
#
# GPT: 1 GiB EFI system partition, the rest LUKS2 with btrfs inside:
# subvolumes for /, /home, /nix, /var/log and a swap file, plus marcin's
# writing subvolumes (Documents, notes, syncthing) with their .snapshots
# subvolumes for modules/system/btrfs.nix (see ./writing.nix). Same layout
# as azazel.
#
# `nixos-anywhere` (refactor stage 3) partitions the disk with this file;
# afterwards it only describes the mounts. Changing it later does NOT
# repartition anything.
#
# Check before installing: `device` (prefer /dev/disk/by-id/...), the swap
# size (hibernation needs at least the RAM size) and the subvolumes.
let
  # nofail: a broken writing subvolume must not stop the boot.
  writingMount = ["compress=zstd" "noatime" "nofail" "x-systemd.requires=home.mount"];
in {
  disko.devices.disk.main = {
    type = "disk";
    device = "@DISK@";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # Used only while formatting: `nix run .#install-host` asks for
            # the passphrase and hands it to the installer at this path
            # (nixos-anywhere --disk-encryption-keys). At boot the initrd
            # asks for it.
            passwordFile = "/tmp/secret.key";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = ["-f"];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "@home/marcin/Documents" = {
                  mountpoint = "/home/marcin/Documents";
                  mountOptions = writingMount;
                };
                "@home/marcin/Documents/.snapshots" = {
                  mountpoint = "/home/marcin/Documents/.snapshots";
                  mountOptions = writingMount;
                };
                "@home/marcin/notes" = {
                  mountpoint = "/home/marcin/notes";
                  mountOptions = writingMount;
                };
                "@home/marcin/notes/.snapshots" = {
                  mountpoint = "/home/marcin/notes/.snapshots";
                  mountOptions = writingMount;
                };
                "@home/marcin/syncthing" = {
                  mountpoint = "/home/marcin/syncthing";
                  mountOptions = writingMount;
                };
                "@home/marcin/syncthing/.snapshots" = {
                  mountpoint = "/home/marcin/syncthing/.snapshots";
                  mountOptions = writingMount;
                };
                "@swap" = {
                  mountpoint = "/.swapvol";
                  swap.swapfile.size = "8G";
                };
              };
            };
          };
        };
      };
    };
  };
}
