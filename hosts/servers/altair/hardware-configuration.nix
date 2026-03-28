# hosts/servers/altair/hardware-configuration.nix
#
# Hardware-specific NixOS configuration for altair.
# Board:  ASUS ProArt X870E-CREATOR WIFI (AM5, BIOS Rev 1605)
# CPU:    AMD Ryzen 9 7900 (Zen 4, 12C/24T, 65W TDP)
# RAM:    64 GB DDR5-4800 (2×32 GB)
# PSU:    Corsair HX1200i (1200W, 80+ Platinum, USB HID monitoring)
# GPUs:   2× Gigabyte RTX 3090 TURBO 24G (blower)
#         PCI 01:00.0 — IOMMU group 14
#         PCI 03:00.0 — IOMMU group 16
# NICs:   enp10s0 — Intel I226-V 2.5G (active, LAN)
#         enp11s0 — Aquantia AQC113 10G (no cable, reserve)
# NVMe:   WD Black SN850X 2TB — nvme-WD_BLACK_SN850X_2000GB_25503L800955
# SATA:   Toshiba N300 14TB  — ata-TOSHIBA_HDWG51EUZSVA_8562A02HFQ6H
#
# ⚠️  boot.initrd.systemd.enable = true is intentional even in Stage 1
#     (passphrase-only mode). It is REQUIRED for future Tang/Clevis binding
#     and costs nothing to set from day 1. Changing it later on an encrypted
#     system requires nixos-rebuild + reboot which is fine, but setting it
#     now avoids the paperwork.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # disko generates systemd mount units, activation scripts, and
    # provides the disko-install compatibility shim.
    ./disko.nix
  ];

  # ---------------------------------------------------------------------------
  # initrd — early boot environment
  # ---------------------------------------------------------------------------

  # systemd-based initrd: required for Clevis/Tang unlock in Phase 0.
  # With classic initrd, network services cannot run before cryptsetup.
  # With systemd initrd, clevis-tang is a proper ordered service unit.
  boot.initrd.systemd.enable = true;

  # Kernel modules needed before root filesystem is available
  boot.initrd.availableKernelModules = [
    "nvme"        # WD SN850X NVMe storage
    "xhci_pci"    # USB 3.x controller (keyboard for fallback passphrase)
    "ahci"        # SATA controller (Toshiba N300 14TB)
    "usbhid"      # USB HID (keyboard/mouse in initrd)
    "usb_storage" # USB mass storage (live USB / recovery)
    "sd_mod"      # SCSI disk (SATA via libata)
  ];

  # dm-crypt provides /dev/mapper/ interface; must be in initrd
  boot.initrd.kernelModules = [
    "dm-crypt"
  ];

  # ---------------------------------------------------------------------------
  # Kernel modules (loaded after userspace starts)
  # ---------------------------------------------------------------------------

  boot.kernelModules = [
    "kvm-amd"     # AMD hardware virtualisation (required for Incus VMs)
    "corsair-psu" # Corsair HXi PSU monitoring via USB HID.
                  # Exposes /sys/class/hwmon/* entries automatically.
                  # prometheus-node-exporter reads these natively —
                  # no liquidctl daemon needed for basic PSU metrics.
  ];

  # ---------------------------------------------------------------------------
  # Kernel parameters
  # ---------------------------------------------------------------------------

  # ⚠️  Set IOMMU from day 1 — retroactively enabling on an encrypted system
  #     is harmless but requires a rebuild + reboot. Better now.
  #     Without IOMMU, Incus VMs cannot do PCIe/GPU passthrough.
  boot.kernelParams = [
    "amd_iommu=on"  # Enable AMD IOMMU (required for GPU passthrough + DMA isolation)
    "iommu=pt"      # Passthrough mode: host DMA not remapped — best perf/security balance
  ];

  # ---------------------------------------------------------------------------
  # Blacklisted modules
  # ---------------------------------------------------------------------------

  # mt7921e: MediaTek Wi-Fi driver for ASUS ProArt onboard Wi-Fi.
  # altair is a headless server — Wi-Fi is not used.
  # Blacklisting eliminates the Wi-Fi attack surface and saves ~4 MB RAM.
  boot.blacklistedKernelModules = [ "mt7921e" ];

  # ---------------------------------------------------------------------------
  # CPU microcode
  # ---------------------------------------------------------------------------

  # AMD microcode patches CPU errata and mitigates hardware vulnerabilities
  # (Spectre/Meltdown variants). Loaded by bootloader before OS — zero runtime cost.
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # ---------------------------------------------------------------------------
  # Firmware
  # ---------------------------------------------------------------------------

  # Enable redistributable firmware blobs (NVIDIA, AMD, NIC firmware)
  hardware.enableRedistributableFirmware = true;

  # ---------------------------------------------------------------------------
  # Platform
  # ---------------------------------------------------------------------------

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
