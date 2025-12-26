# VM Test Configuration
# Minimal configuration for VirtualBox/QEMU testing
{ config, pkgs, lib, ... }:

{
  # ========================================
  # DISABLE WiFi module for VM (no WiFi hardware)
  # ========================================
  disabledModules = [ ../../modules/system/wifi.nix ];

  # ========================================
  # BASIC SYSTEM SETTINGS
  # ========================================
  networking.hostName = "testvm";
  
  # Disable wireless (VM doesn't have WiFi)
  networking.wireless.enable = false;
  
  # ========================================
  # VM-SPECIFIC SERVICES
  # ========================================
  # QEMU guest agent for better VM integration
  services.qemuGuest.enable = true;
  
  # Spice agent for clipboard sharing and display scaling
  services.spice-vdagentd.enable = true;
  
  # Disable TLP (no battery management in VM)
  services.tlp.enable = lib.mkForce false;
  
  # ========================================
  # USER CONFIGURATION
  # ========================================
  users.users.marcin = {
    isNormalUser = true;
    description = "Marcin";
    extraGroups = [ "wheel" "networkmanager" ];
    
    # Explicit UID to ensure correct file ownership
    uid = 1000;
    
    # SSH key for remote access
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqKdPGwVs6FMLzRMW06vTPi7t4pGsXTc5sNBHW9LMx marcin@tabby"
    ];
  };
  
  # ========================================
  # SYSTEM VERSION
  # ========================================
  system.stateVersion = "25.11";
}
