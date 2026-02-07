# ./hosts/azazel/configuration.nix
# Azazel - ThinkPad T16 Gen3 (production host)
# Hardware: 128GB RAM, nvme, battery
{
  pkgs,
  hostname,
  ...
}: {
  # Hostname
  networking.hostName = hostname;

  # Enable universal secrets management
  services.secrets.enable = true;
  services.fwupd.enable = true;

  # Import host-specific modules
  imports = [
    ../../modules/laptop/tlp.nix
    ../../modules/laptop/hibernate.nix
    ../../modules/laptop/suspend-fix.nix
    ../../modules/laptop/acpi-fix.nix
    ../../modules/laptop/thunderbolt.nix
    ../../modules/system/gaming.nix
    ../../modules/laptop/fingerprint.nix
  ];

  # Allow automatic hibernation. It automaticly handles offset calcukation and setup via EFI variables
  boot.initrd.systemd.enable = true;

  # User configuration
  users.users.marcin = {
    isNormalUser = true;
    description = "Marcin";
    extraGroups = ["networkmanager" "wheel" "gamemode" "input" "uinput" "plugdev"];
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
    killall
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
