# WiFi Configuration with NetworkManager
# Hybrid approach: Declarative permanent networks + Imperative ad-hoc networks
# 
# Usage:
# - Permanent networks (home, work) defined here with encrypted passwords
# - Ad-hoc networks (cafes, hotels) added with: nmcli device wifi connect "SSID" password "pass"

{ config, lib, pkgs, ... }:

{
  # Disable wpa_supplicant (conflicts with NetworkManager)
  networking.wireless.enable = lib.mkForce false;
  
  # Enable NetworkManager
  networking.networkmanager = {
    enable = true;
    
    # Better performance (disable power saving)
    wifi.powersave = false;
    
    # Allow imperative network additions via nmcli/GUI
    # Networks added with nmcli will be stored in /etc/NetworkManager/system-connections/
  };
  
  # ==========================================
  # SOPS Secrets for WiFi Passwords
  # ==========================================
  
  # Home WiFi password
  sops.secrets."wifi/home-psk" = {
    sopsFile = ../../secrets/wifi.yaml;
    restartUnits = [ "NetworkManager.service" ];
    mode = "0600";
  };
  
  # Work WiFi password
  sops.secrets."wifi/work-psk" = {
    sopsFile = ../../secrets/wifi.yaml;
    restartUnits = [ "NetworkManager.service" ];
    mode = "0600";
  };
  
  # Parents/Frequently visited WiFi password (optional)
  sops.secrets."wifi/parents-psk" = {
    sopsFile = ../../secrets/wifi.yaml;
    restartUnits = [ "NetworkManager.service" ];
    mode = "0600";
  };
  
  # ==========================================
  # Declarative WiFi Profiles (Permanent Networks)
  # ==========================================
  
  # Home WiFi - Highest priority
  environment.etc."NetworkManager/system-connections/Home.nmconnection" = {
    mode = "0600";
    text = ''      
      [connection]
      id=Home
      uuid=HOME_UUID_PLACEHOLDER
      type=wifi
      autoconnect=true
      autoconnect-priority=100
      permissions=

      [wifi]
      mode=infrastructure
      ssid=YOUR_HOME_SSID_HERE

      [wifi-security]
      auth-alg=open
      key-mgmt=wpa-psk
      psk-flags=0

      [ipv4]
      method=auto

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
  };
  
  # Work WiFi - Medium priority
  environment.etc."NetworkManager/system-connections/Work.nmconnection" = {
    mode = "0600";
    text = ''      
      [connection]
      id=Work
      uuid=WORK_UUID_PLACEHOLDER
      type=wifi
      autoconnect=true
      autoconnect-priority=50
      permissions=

      [wifi]
      mode=infrastructure
      ssid=YOUR_WORK_SSID_HERE

      [wifi-security]
      auth-alg=open
      key-mgmt=wpa-psk
      psk-flags=0

      [ipv4]
      method=auto

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
  };
  
  # Parents WiFi - Lower priority (optional)
  environment.etc."NetworkManager/system-connections/Parents.nmconnection" = {
    mode = "0600";
    text = ''      
      [connection]
      id=Parents
      uuid=PARENTS_UUID_PLACEHOLDER
      type=wifi
      autoconnect=true
      autoconnect-priority=30
      permissions=

      [wifi]
      mode=infrastructure
      ssid=YOUR_PARENTS_SSID_HERE

      [wifi-security]
      auth-alg=open
      key-mgmt=wpa-psk
      psk-flags=0

      [ipv4]
      method=auto

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
  };
  
  # ==========================================
  # Inject Passwords from SOPS into Profiles
  # ==========================================
  
  # This runs after 'etc' activation to inject decrypted passwords
  system.activationScripts.wifi-inject-passwords = lib.stringAfter [ "etc" ] ''
    # Home WiFi
    if [ -f ${config.sops.secrets."wifi/home-psk".path} ]; then
      HOME_PSK=$(cat ${config.sops.secrets."wifi/home-psk".path})
      ${pkgs.gnused}/bin/sed -i "s|psk-flags=0|psk=$HOME_PSK\npsk-flags=0|" \
        /etc/NetworkManager/system-connections/Home.nmconnection 2>/dev/null || true
    fi
    
    # Work WiFi
    if [ -f ${config.sops.secrets."wifi/work-psk".path} ]; then
      WORK_PSK=$(cat ${config.sops.secrets."wifi/work-psk".path})
      ${pkgs.gnused}/bin/sed -i "s|psk-flags=0|psk=$WORK_PSK\npsk-flags=0|" \
        /etc/NetworkManager/system-connections/Work.nmconnection 2>/dev/null || true
    fi
    
    # Parents WiFi
    if [ -f ${config.sops.secrets."wifi/parents-psk".path} ]; then
      PARENTS_PSK=$(cat ${config.sops.secrets."wifi/parents-psk".path})
      ${pkgs.gnused}/bin/sed -i "s|psk-flags=0|psk=$PARENTS_PSK\npsk-flags=0|" \
        /etc/NetworkManager/system-connections/Parents.nmconnection 2>/dev/null || true
    fi
    
    # Reload NetworkManager to pick up changes
    if systemctl is-active NetworkManager.service >/dev/null 2>&1; then
      ${pkgs.systemd}/bin/systemctl reload NetworkManager.service || true
    fi
  '';
  
  # ==========================================
  # NetworkManager CLI Aliases
  # ==========================================
  
  # Add helpful aliases for users (in home.nix)
  # wifi-list    = nmcli device wifi list
  # wifi-connect = nmcli device wifi connect
  # wifi-status  = nmcli connection show --active
  # wifi-forget  = nmcli connection delete
}
