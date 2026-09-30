# Disk layout of @HOST@ (disko), from hosts/templates/disko/btrfs.nix.
#
# GPT: 1 GiB EFI system partition, the rest btrfs with subvolumes for /,
# /home, /nix, /var/log and a swap file.
#
# `nixos-anywhere` (refactor stage 3) partitions the disk with this file;
# afterwards it only describes the mounts. Changing it later does NOT
# repartition anything.
#
# Check before installing: `device` (prefer /dev/disk/by-id/...), the swap
# size (hibernation needs at least the RAM size) and the subvolumes.
{
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
}
