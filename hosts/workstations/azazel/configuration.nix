# hosts/workstations/azazel/configuration.nix
#
# Azazel — ThinkPad T16 Gen3 (primary production host).
# Hardware: AMD Ryzen, 128 GB RAM, NVMe, no discrete GPU.
#
# This file contains ONLY what is unique to this physical machine:
# hostname, user account, state version, and hardware-specific boot
# settings. Everything else — desktop environment, power management,
# optional services — lives in profile.nix.
{
  pkgs,
  hostname,
  ...
}: {
  networking.hostName = hostname;

  # Firmware update support via LVFS.
  services.fwupd.enable = true;

  # systemd in initrd is required for the automatic hibernation offset
  # calculation and EFI variable setup used by hibernate.nix.
  boot.initrd.systemd.enable = true;

  users.users.marcin = {
    isNormalUser  = true;
    description   = "Marcin";
    extraGroups   = [ "networkmanager" "wheel" "gamemode" "input" "uinput" "plugdev" ];
  };

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
  ];

  services.syncthing = {
    enable           = true;
    openDefaultPorts = true;
    user             = "marcin";
    dataDir          = "/home/marcin";
    configDir        = "/home/marcin/.config/syncthing";
  };

  # DO NOT change stateVersion after the initial installation.
  # It controls the format of stateful data (databases, dotfiles) and
  # changing it will not upgrade anything — it only breaks assumptions.
  system.stateVersion = "25.11";
}
