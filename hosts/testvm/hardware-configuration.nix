# Dummy hardware configuration for testvm
# This is a virtual machine, hardware auto-detected at install time
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.kernelModules = [ "kvm-intel" ];
  
  # Auto-detect filesystems
  fileSystems."/" = { 
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  
  swapDevices = [ ];
  
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
