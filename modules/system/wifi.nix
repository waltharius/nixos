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
      id=Home
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
      method=auto

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
  };

  environment.etc."NetworkManager/system-connections/hegemonia5G-2.nmconnection" = {
    mode = "0600";
    text = ''
      [connection]
      id=Work
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
      method=auto

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
  };

  environment.etc."NetworkManager/system-connections/salon_new24.nmconnection" = {
    mode = "0600";
    text = ''
      [connection]
      id=Parents
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
  system.activationScripts.wifi-inject-passwords = lib.stringAfter ["etc"] ''
    # Source dotenv file from sops secrets
    WIFI_ENV="${config.sops.secrets."wifi-env-file".path}"
    
    if [ -f "$WIFI_ENV" ]; then
      # Source environment variables from decrypted file
      set -a  # automatically export all variables
      source "$WIFI_ENV"
      set +a

      # Inject password into hegemonia5G-1 connection
      if [ -n "$HEGEMONIA5G_1" ]; then
        ${pkgs.gnused}/bin/sed -i "s|psk-flags=0|psk=$HEGEMONIA5G_1\npsk-flags=0|" \
          /etc/NetworkManager/system-connections/hegemonia5G-1.nmconnection 2>/dev/null || true
      fi

      # Inject password into hegemonia5G-2 connection
      if [ -n "$HEGEMONIA5G_2" ]; then
        ${pkgs.gnused}/bin/sed -i "s|psk-flags=0|psk=$HEGEMONIA5G_2\npsk-flags=0|" \
          /etc/NetworkManager/system-connections/hegemonia5G-2.nmconnection 2>/dev/null || true
      fi

      # Inject password into salon_new24 connection
      if [ -n "$SALON_NEW24" ]; then
        ${pkgs.gnused}/bin/sed -i "s|psk-flags=0|psk=$SALON_NEW24\npsk-flags=0|" \
          /etc/NetworkManager/system-connections/salon_new24.nmconnection 2>/dev/null || true
      fi

      # Reload NetworkManager to apply changes
      if systemctl is-active NetworkManager.service >/dev/null 2>&1; then
        ${pkgs.systemd}/bin/systemctl reload NetworkManager.service 2>/dev/null || true
      fi
    else
      echo "Warning: WiFi secrets file not found at $WIFI_ENV" >&2
      echo "WiFi networks will be created without passwords." >&2
      echo "You can connect manually using NetworkManager GUI." >&2
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
