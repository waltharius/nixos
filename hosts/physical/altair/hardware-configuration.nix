# hosts/physical/altair/hardware-configuration.nix
#
# Hardware-specific NixOS configuration for altair.
# Board:  ASUS ProArt X870E-CREATOR WIFI (AM5, BIOS Rev 1605)
# CPU:    AMD Ryzen 9 7900 (Zen 4, 12C/24T, 65W TDP)
# RAM:    64 GB DDR5-4800 (2×32 GB)
# PSU:    Corsair HX1200i (1200W, 80+ Platinum, USB HID monitoring)
# GPUs:   2× Gigabyte RTX 3090 TURBO 24G (blower)
#         PCI 01:00.0 — IOMMU group 14
#         PCI 03:00.0 — IOMMU group 16
# NICs:   enp10s0 — Intel I226-V 2.5G (MAC: 30:c5:99:5b:ec:97, active, LAN)
#         enp11s0 — Aquantia AQC113 10G (no cable, reserve)
# NVMe:   WD Black SN850X 2TB — nvme-WD_BLACK_SN850X_2000GB_25503L800955
# SATA:   Toshiba N300 14TB  — ata-TOSHIBA_HDWG51EUZSVA_8562A02HFQ6H
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    ./disko.nix
  ];

  # Systemd-based initrd. Required for boot.initrd.systemd.ssh and
  # boot.initrd.systemd.network to be available (see initrd-ssh.nix).
  # Also enables better LUKS integration via systemd-cryptsetup.
  boot.initrd.systemd.enable = true;

  # Modules available during initrd (before root FS is mounted).
  # igc is the driver for the Intel I226-V NIC — needed for initrd networking.
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "igc"
  ];

  boot.initrd.kernelModules = [
    "dm-crypt"
  ];

  boot.kernelModules = [
    "kvm-amd"
    "corsair-psu"
  ];

  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
    "pcie_aspm=off" # Fixes AQC113 and Intel I226-V PCIe instability
  ];

  # mt7921e is the MediaTek Wi-Fi driver built into the X870E board.
  # Blacklisted because the server uses the wired Intel NIC exclusively
  # and loading the Wi-Fi driver adds unnecessary init time.
  boot.blacklistedKernelModules = ["mt7921e"];

  # Intel I226-V 2.5G errata — force 1 Gbps to eliminate hardware reset bug
  # under sustained transfers. 1G is stable; 2.5G is not on this silicon rev.
  systemd.network.links."10-intel-lan" = {
    matchConfig.MACAddress = "30:c5:99:5b:ec:97";
    linkConfig = {
      Speed = "1000";
      Duplex = "full";
    };
  };

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
