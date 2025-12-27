# WiFi Configuration with NetworkManager
# Hybrid approach: Declarative permanent networks + Imperative ad-hoc networks
#
# Usage:
# - Permanent networks (home, work) defined here with encrypted passwords
# - Ad-hoc networks (cafes, hotels) added with: nmcli device wifi connect "SSID" password "pass"
{
  config,
  lib,
  pkgs,
  ...
}: {
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

  # Entire wifi.env file containing all WiFi passwords
  sops.secrets."wifi-env-file" = {
    sopsFile = ../../secrets/wifi.env;
    format = "dotenv";
    restartUnits = ["NetworkManager.service"];
    mode = "0600";
    owner = "root";
    group = "root";
  };

  # ==========================================
  # Declarative WiFi Profiles (Permanent Networks)
  # ==========================================

  # Home WiFi - Highest priority
  environment.etc."NetworkManager/system-connections/hegemonia5G-1.nmconnection" = {
    mode = "0600";
    text = ''
      [connection]
      id=hegemonia5G-1
      type=wifi
      autoconnect=true
      autoconnect-priority=100
      permissions=

      [wifi]
      mode=infrastructure
      ssid=hegemonia5G-1

      [wifi-security]
      auth-alg=open
      key-mgmt=wpa-psk
      psk-flags=0

      [ipv4]
      address1=192.168.50.81/24
      dns=192.168.50.1;
      dns-search=home.lan;
      gateway=192.168.50.1
      method=manual

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
  };

  environment.etc."NetworkManager/system-connections/hegemonia5G-2.nmconnection" = {
    mode = "0600";
    text = ''
      [connection]
      id=hegemonia5G-2
      type=wifi
      autoconnect=true
      autoconnect-priority=50
      permissions=

      [wifi]
      mode=infrastructure
      ssid=hegemonia5G-2

      [wifi-security]
      auth-alg=open
      key-mgmt=wpa-psk
      psk-flags=0

      [ipv4]
      address1=192.168.50.81/24
      dns=192.168.50.1;
      dns-search=home.lan;
      gateway=192.168.50.1
      method=manual

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
  };

  environment.etc."NetworkManager/system-connections/salon_new24.nmconnection" = {
    mode = "0600";
    text = ''
      [connection]
      id=salon_new24
      type=wifi
      autoconnect=true
      autoconnect-priority=30
      permissions=

      [wifi]
      mode=infrastructure
      ssid=salon_new24

      [wifi-security]
      auth-alg=open
      key-mgmt=wpa-psk
      psk-flags=0

      [ipv4]
      address1=192.168.50.81/24
      dns=192.168.50.1;
      dns-search=home.lan;
      gateway=192.168.50.1
      method=manual

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
  };

  # ==========================================
  # Inject Passwords from SOPS into Profiles
  # ==========================================

  # This runs after 'etc' activation to inject decrypted passwords
  # Note: sops-nix runs as a systemd service, not an activation script
  # So secrets may not be available during first rebuild - they'll work after reboot
  system.activationScripts.wifi-inject-passwords = lib.stringAfter ["etc"] ''
    # Use hardcoded path to avoid circular dependency
    WIFI_ENV="/run/secrets/wifi-env-file"
    
    if [ -f "$WIFI_ENV" ]; then
      echo "WiFi: Injecting passwords from $WIFI_ENV"
      
      # Source environment variables from decrypted file
      set -a
      source "$WIFI_ENV" || {
        echo "WiFi: ERROR - Failed to source $WIFI_ENV" >&2
        exit 0
      }
      set +a

      # Inject password into hegemonia5G-1 connection
      if [ -n "$HEGEMONIA5G_1" ]; then
        echo "WiFi: Injecting password for hegemonia5G-1"
        ${pkgs.gnused}/bin/sed -i "/\[wifi-security\]/a psk=$HEGEMONIA5G_1" \
          /etc/NetworkManager/system-connections/hegemonia5G-1.nmconnection 2>/dev/null || true
      fi

      # Inject password into hegemonia5G-2 connection
      if [ -n "$HEGEMONIA5G_2" ]; then
        echo "WiFi: Injecting password for hegemonia5G-2"
        ${pkgs.gnused}/bin/sed -i "/\[wifi-security\]/a psk=$HEGEMONIA5G_2" \
          /etc/NetworkManager/system-connections/hegemonia5G-2.nmconnection 2>/dev/null || true
      fi

      # Inject password into salon_new24 connection
      if [ -n "$SALON_NEW24" ]; then
        echo "WiFi: Injecting password for salon_new24"
        ${pkgs.gnused}/bin/sed -i "/\[wifi-security\]/a psk=$SALON_NEW24" \
          /etc/NetworkManager/system-connections/salon_new24.nmconnection 2>/dev/null || true
      fi

      # Set correct permissions
      chmod 600 /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null || true

      # Reload NetworkManager to apply changes
      if systemctl is-active NetworkManager.service >/dev/null 2>&1; then
        echo "WiFi: Reloading NetworkManager"
        ${pkgs.systemd}/bin/systemctl reload NetworkManager.service 2>/dev/null || true
      fi
    else
      echo "WiFi: WARNING - secrets file not found at $WIFI_ENV" >&2
      echo "WiFi: Networks will be created without passwords" >&2
      echo "WiFi: After first boot, secrets will be available and you can run:" >&2
      echo "WiFi:   sudo /nix/var/nix/profiles/system/activate" >&2
      echo "WiFi:   sudo systemctl restart NetworkManager" >&2
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
