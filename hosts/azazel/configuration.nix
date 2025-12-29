# Azazel - ThinkPad T16 Gen3 (production host)
# Hardware: 128GB RAM, nvme, battery
{
  config,
  pkgs,
  lib,
  hostname,
  ...
}: {
  # Hostname
  networking.hostName = hostname;

  # Fingerprint reader
  services.fprintd.enable = true;

  # Import host-specific modules
  imports = [
    ../../modules/laptop/tlp.nix
    ../../modules/laptop/hibernate.nix
  ];

  # User configuration
  users.users.marcin = {
    isNormalUser = true;
    description = "Marcin";
    extraGroups = ["networkmanager" "wheel"];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable experimental Nix features
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # System packages
  environment.systemPackages = with pkgs; [
    neovim
    vim
    wget
    curl
    git
    btop
    alacritty
    ptyxis
  ];

  # Enable Syncthing
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "marcin";
    dataDir = "/home/marcin";
    configDir = "/home/marcin/.config/syncthing";
  };

  # State version - DO NOT CHANGE after initial installation
  system.stateVersion = "25.11";
}
