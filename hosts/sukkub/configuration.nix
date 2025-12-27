# Sukkub - Lenovo ThinkPad P50 (test/POC host)
# Hardware: nvme, no battery
{ config, pkgs, lib, hostname, ... }:

{
  # Hostname
  networking.hostName = hostname;
  
  # Import host-specific modules
  imports = [
  ../../modules/services/ssh.nix
  ];
  
  # User configuration
  users.users.marcin = {
    isNormalUser = true;
    description = "Marcin";
    extraGroups = [ "networkmanager" "wheel" ];
    
    # SSH authorized keys for remote access
    # TODO: Replace with your actual public key from ~/.ssh/id_ed25519_tabby.pub
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025" 
    ];
  };
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  
  # Enable experimental Nix features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
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
