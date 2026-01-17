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
  hostname,
  ...
}: let
  # Host-specific IP addresses
  hostIP =
    {
      azazel = "192.168.50.80";
      sukkub = "192.168.50.81";
    }.${
      hostname
    } or "192.168.50.99"; # Fallback IP if host unknown
in {
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
      address1=${hostIP}/24
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
      address1=${hostIP}/24
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
      address1=${hostIP}/24
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
  # Uses Python for safe handling of passwords with special characters
  system.activationScripts.wifi-inject-passwords = lib.stringAfter ["etc"] ''
        WIFI_ENV="/run/secrets/wifi-env-file"

        if [ -f "$WIFI_ENV" ]; then
          echo "WiFi: Injecting passwords from $WIFI_ENV"

          # Use Python for safe password injection (handles all special chars including backslashes)
          ${pkgs.python3}/bin/python3 << 'PYTHON_EOF'
    import os
    import sys

    try:
        # Read secrets from dotenv file
        secrets = {}
        with open("/run/secrets/wifi-env-file", "r") as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    secrets[key] = value

        # Map connection names to their password variables
        connections = {
            "hegemonia5G-1": secrets.get("HEGEMONIA5G_1", ""),
            "hegemonia5G-2": secrets.get("HEGEMONIA5G_2", ""),
            "salon_new24": secrets.get("SALON_NEW24", ""),
        }

        # Inject passwords into nmconnection files
        for conn_name, password in connections.items():
            if not password:
                print(f"WiFi: WARNING - No password found for {conn_name}")
                continue

            file_path = f"/etc/NetworkManager/system-connections/{conn_name}.nmconnection"

            if not os.path.exists(file_path):
                print(f"WiFi: WARNING - Connection file not found: {file_path}")
                continue

            try:
                # Read current file content
                with open(file_path, "r") as f:
                    content = f.read()

                # Check if password already injected
                if "\npsk=" in content:
                    print(f"WiFi: Password already present in {conn_name}, skipping")
                    continue

                # Inject password after [wifi-security] section using safe string split
                # This avoids regex interpretation of backslash sequences like \x, \n, etc.
                if "\n[wifi-security]\n" in content:
                    parts = content.split("\n[wifi-security]\n", 1)
                    # Build new content with password safely inserted (no escaping issues)
                    content = (
                        parts[0] +
                        "\n[wifi-security]\n" +
                        f"psk={password}\n" +
                        parts[1]
                    )
                else:
                    print(f"WiFi: ERROR - No [wifi-security] section found in {conn_name}")
                    continue

                # Write back to file
                with open(file_path, "w") as f:
                    f.write(content)

                # Set correct permissions
                os.chmod(file_path, 0o600)

                print(f"WiFi: Successfully injected password for {conn_name}")

            except Exception as e:
                print(f"WiFi: ERROR injecting password for {conn_name}: {e}", file=sys.stderr)
                continue

        print("WiFi: Password injection completed")

    except Exception as e:
        print(f"WiFi: FATAL ERROR: {e}", file=sys.stderr)
        sys.exit(0)  # Don't fail the activation

    PYTHON_EOF

          # Reload NetworkManager to apply changes
          if systemctl is-active NetworkManager.service >/dev/null 2>&1; then
            echo "WiFi: Reloading NetworkManager"
            ${pkgs.systemd}/bin/systemctl reload NetworkManager.service 2>/dev/null || true
          fi
        else
          echo "WiFi: WARNING - secrets file not found at $WIFI_ENV" >&2
          echo "WiFi: Networks will be created without passwords" >&2
          echo "WiFi: After reboot, run: sudo /nix/var/nix/profiles/system/activate" >&2
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
