# hosts/workstations/sukkub/configuration.nix
#
# Sukkub — ThinkPad P50 (test/POC host).
# Hardware: Intel Xeon, 32 GB RAM, NVMe, NVIDIA Quadro M2000M (Maxwell).
#
# This file contains ONLY what is unique to this physical machine:
# hostname, user account, state version, hardware-specific boot settings,
# and quirks that apply nowhere else. Everything else lives in profile.nix.
{
  pkgs,
  hostname,
  ...
}: {
  networking.hostName = hostname;

  # systemd in initrd is required for the automatic hibernation offset
  # calculation and EFI variable setup used by hibernate.nix.
  boot.initrd.systemd.enable = true;

  users.users.marcin = {
    isNormalUser  = true;
    description   = "Marcin";
    extraGroups   = [ "networkmanager" "wheel" "gamemode" "input" "uinput" "plugdev" ];
    # Authorised key for remote access from the Tabby terminal.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
    ];
  };

  # Disable serial console gettys. sukkub has no serial hardware;
  # leaving these enabled causes ~16 s boot delays waiting for
  # non-existent TTY devices.
  systemd.services."serial-getty@ttyS0".enable = false;
  systemd.services."serial-getty@ttyS1".enable = false;
  systemd.services."serial-getty@ttyS2".enable = false;
  systemd.services."serial-getty@ttyS3".enable = false;
  systemd.services."serial-getty@".enable       = false;

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    neovim
    vim
    wget
    curl
    git
    btop
    alacritty
    ptyxis
    killall
    texlive.combined.scheme-medium
  ];

  services.syncthing = {
    enable           = true;
    openDefaultPorts = true;
    user             = "marcin";
    dataDir          = "/home/marcin";
    configDir        = "/home/marcin/.config/syncthing";
  };

  # DO NOT change stateVersion after the initial installation.
  system.stateVersion = "25.11";
}
