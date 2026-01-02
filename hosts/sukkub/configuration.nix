# Sukkub - Lenovo ThinkPad P50 (test/POC host)
# Hardware: nvme, no battery
{
  config,
  pkgs,
  lib,
  hostname,
  ...
}: {
  # Hostname
  networking.hostName = hostname;

  # Import host-specific modules
  imports = [
    ../../modules/laptop/tlp.nix
    ../../modules/laptop/hibernate.nix
    ../../modules/laptop/acpi-suspend.nix
    ../../modules/laptop/thunderbolt.nix
    ../../modules/system/gaming.nix
    ../../modules/system/grub.nix
  ];

  # Allow automatic hibernation. It automaticly handles offset calcukation and setup via EFI variables
  boot.initrd.systemd.enable = true;

  # User configuration
  users.users.marcin = {
    isNormalUser = true;
    description = "Marcin";
    extraGroups = ["networkmanager" "wheel" "gamemode" "input" "uinput" "plugdev"];

    # SSH authorized keys for remote access
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
    ];
  };

  # Disable serial console services (not needed on laptops)
  # This eliminates 16-second boot delays for non-existent hardware
  systemd.services = {
    "serial-getty@ttyS0".enable = false;
    "serial-getty@ttyS1".enable = false;
    "serial-getty@ttyS2".enable = false;
    "serial-getty@ttyS3".enable = false;
  };

  # Or more elegantly - disable all serial gettys at once
  systemd.services."serial-getty@".enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable experimental Nix features
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # System packages
  environment.systemPackages = with pkgs; [
    tlp
    #mesa-demos
    #vulkan-tools
    texlive.combined.scheme-medium
  ];

  # State version - DO NOT CHANGE after initial installation
  system.stateVersion = "25.11";
}
