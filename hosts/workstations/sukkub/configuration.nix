# hosts/workstations/sukkub/configuration.nix
#
# Sukkub — ThinkPad P50 (test/POC host).
# Hardware: Intel Xeon, 32 GB RAM, NVMe, NVIDIA Quadro M2000M (Maxwell).
#
# This file contains ONLY what is unique to this physical machine:
# hostname, state version, hardware-specific boot settings and quirks that
# apply nowhere else. Hardware modules are imported in custom.nix;
# accounts and programs come from hosts/machines/<host>.nix.
{hostname, ...}: {
  networking.hostName = hostname;

  # systemd in initrd is required for the automatic hibernation offset
  # calculation and EFI variable setup used by hibernate.nix.
  boot.initrd.systemd.enable = true;

  # Authorised key for remote access to marcin from the Tabby terminal.
  # Only on sukkub; the account itself is in users/marcin/account.nix.
  users.users.marcin.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
  ];

  # Disable serial console gettys. sukkub has no serial hardware;
  # leaving these enabled causes ~16 s boot delays waiting for
  # non-existent TTY devices.
  systemd.services."serial-getty@ttyS0".enable = false;
  systemd.services."serial-getty@ttyS1".enable = false;
  systemd.services."serial-getty@ttyS2".enable = false;
  systemd.services."serial-getty@ttyS3".enable = false;
  systemd.services."serial-getty@".enable = false;

  nixpkgs.config.allowUnfree = true;
  # Required for NVIDIA legacy drivers (470.xx for Maxwell/Quadro M2000M).
  # legacy_470 is not covered by the generic allowUnfree flag — it needs
  # an explicit licence acceptance per NVIDIA's redistribution terms.
  nixpkgs.config.nvidia.acceptLicense = true;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "marcin";
    dataDir = "/home/marcin";
    configDir = "/home/marcin/.config/syncthing";
  };

  # DO NOT change stateVersion after the initial installation.
  system.stateVersion = "25.11";
}
