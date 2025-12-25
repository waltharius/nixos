# WiFi Setup Guide - Encrypted Passwords

This guide shows how to configure WiFi networks with encrypted passwords using NetworkManager and SOPS.

## 🎯 How It Works

### Hybrid Approach:

1. **Declarative (Permanent)**: Home, Work, Parents networks in config
2. **Imperative (Ad-hoc)**: Cafes, hotels, conferences via `nmcli`

### Benefits:

- ✅ **Permanent networks** auto-connect on all hosts
- ✅ **Passwords encrypted** in git with SOPS
- ✅ **Ad-hoc networks** added instantly without rebuild
- ✅ **No plaintext passwords** in Nix store

---

## 📋 Initial Setup

### Step 1: Create WiFi Secrets File

On your management machine (Fedora):

```bash
cd ~/nixos

# Create encrypted WiFi secrets
sops secrets/wifi.yaml
```

In the SOPS editor, add your networks:

```yaml
# Format: Key-value pairs for each network

# Home WiFi password
wifi/home-psk: TwojeHasloDomowe123

# Work WiFi password  
wifi/work-psk: HasloDoPracy456

# Parents WiFi password (optional)
wifi/parents-psk: HasloRodzicow789
```

**Save and exit** - SOPS will encrypt automatically.

### Step 2: Update WiFi Module Configuration

Edit `modules/system/wifi.nix` and replace placeholders:

```nix
# Find these lines and update:

# Home network
ssid=YOUR_HOME_SSID_HERE      # Change to: ssid=MojaDomowaSiec
uuid=HOME_UUID_PLACEHOLDER     # Change to: uuid=a1b2c3d4-1234-5678-90ab-cdef12345678

# Work network  
ssid=YOUR_WORK_SSID_HERE       # Change to: ssid=FirmaWiFi
uuid=WORK_UUID_PLACEHOLDER      # Change to: uuid=b2c3d4e5-2345-6789-01bc-def123456789

# Parents network (optional)
ssid=YOUR_PARENTS_SSID_HERE    # Change to: ssid=RodziceWiFi
uuid=PARENTS_UUID_PLACEHOLDER   # Change to: uuid=c3d4e5f6-3456-7890-12cd-ef1234567890
```

**Generate UUIDs:**
```bash
# Generate random UUIDs for each network
uuidgen  # Run 3 times for 3 networks
```

### Step 3: Enable WiFi Module

Edit `flake.nix` and add WiFi module to imports:

```nix
mkHost = hostname: system: nixpkgs.lib.nixosSystem {
  modules = [
    # ... existing modules ...
    ./modules/system/wifi.nix  # ← ADD THIS
  ];
};
```

### Step 4: Add WiFi Aliases to home.nix

Edit `users/marcin/home.nix` in `shellAliases` section:

```nix
shellAliases = {
  # ... existing aliases ...
  
  # WiFi management
  wifi-list = "nmcli device wifi list";
  wifi-connect = "nmcli device wifi connect";
  wifi-status = "nmcli connection show --active";
  wifi-forget = "nmcli connection delete";
  wifi-scan = "nmcli device wifi rescan";
};
```

### Step 5: Re-encrypt Secrets

After updating `.sops.yaml` with WiFi rule:

```bash
cd ~/nixos

# Re-encrypt for all hosts
sops updatekeys secrets/wifi.yaml

# Verify
sops -d secrets/wifi.yaml
# Should show your passwords
```

### Step 6: Commit and Push

```bash
git add .sops.yaml secrets/wifi.yaml modules/system/wifi.nix users/marcin/home.nix flake.nix
git commit -m "Add: WiFi configuration with encrypted passwords"
git push
```

---

## 🚀 Deploy on Hosts

### On Sukkub/Azazel:

```bash
# Pull changes
cd ~/nixos
sudo git pull

# Rebuild
sudo nixos-rebuild switch --flake ~/nixos#sukkub

# Check WiFi status
nmcli connection show
# Should show: Home, Work, Parents

# Should auto-connect to strongest network
wifi-status
```

---

## 🔧 Daily Usage

### Permanent Networks (Auto-Connect)

These are in your config - they just work:

```bash
# At home
# → Automatically connects to "Home"

# At work
# → Automatically connects to "Work"

# At parents
# → Automatically connects to "Parents"
```

### Ad-hoc Networks (Cafes, Hotels)

```bash
# 1. List available networks
wifi-list
# Or: nmcli device wifi list

# 2. Connect to network
wifi-connect "CafeLatte" password "guest1234"
# Or: nmcli device wifi connect "CafeLatte" password "guest1234"

# 3. Use internet...

# 4. Forget network when leaving
wifi-forget "CafeLatte"
# Or: nmcli connection delete "CafeLatte"
```

### GUI Method (GNOME)

1. Click WiFi icon (top-right corner)
2. Select network from list
3. Enter password
4. Connect ✓

---

## 📝 Adding New Permanent Network

### Example: Add "Office2" network

#### 1. Add password to secrets:

```bash
cd ~/nixos
sops secrets/wifi.yaml
```

Add:
```yaml
wifi/office2-psk: NoveHasloOffice2
```

#### 2. Add to `modules/system/wifi.nix`:

```nix
# Add SOPS secret
sops.secrets."wifi/office2-psk" = {
  sopsFile = ../../secrets/wifi.yaml;
  restartUnits = [ "NetworkManager.service" ];
  mode = "0600";
};

# Add NetworkManager profile
environment.etc."NetworkManager/system-connections/Office2.nmconnection" = {
  mode = "0600";
  text = ''
    [connection]
    id=Office2
    uuid=NEW_UUID_HERE  # Generate with: uuidgen
    type=wifi
    autoconnect=true
    autoconnect-priority=40

    [wifi]
    ssid=Office2WiFi

    [wifi-security]
    key-mgmt=wpa-psk
    psk-flags=0

    [ipv4]
    method=auto

    [ipv6]
    method=auto
  '';
};

# Add password injection
system.activationScripts.wifi-inject-passwords = lib.stringAfter [ "etc" ] ''
  # ... existing injections ...
  
  # Office2 WiFi
  if [ -f ${config.sops.secrets."wifi/office2-psk".path} ]; then
    OFFICE2_PSK=$(cat ${config.sops.secrets."wifi/office2-psk".path})
    ${pkgs.gnused}/bin/sed -i "s|psk-flags=0|psk=$OFFICE2_PSK\npsk-flags=0|" \
      /etc/NetworkManager/system-connections/Office2.nmconnection 2>/dev/null || true
  fi
'';
```

#### 3. Deploy:

```bash
sops updatekeys secrets/wifi.yaml
git add secrets/wifi.yaml modules/system/wifi.nix
git commit -m "Add: Office2 WiFi network"
git push

# On all hosts
sudo nixos-rebuild switch --flake ~/nixos#hostname
```

---

## 🔐 Security

### What's Safe:

- ✅ **secrets/wifi.yaml** - Encrypted, safe to commit
- ✅ **SSID names** - Not secret, safe in config
- ✅ **UUIDs** - Random identifiers, not sensitive

### What's Protected:

- 🔒 **WiFi passwords** - Encrypted in git
- 🔒 **Decrypted secrets** - Only in `/run/secrets/` (tmpfs)
- 🔒 **Age keys** - Never committed (`/var/lib/sops-nix/key.txt`)

### Attack Vectors:

- ❌ **Nix store**: Passwords NOT stored here
- ❌ **Git history**: Only encrypted data
- ✅ **Live system**: Needs age key to decrypt

---

## 🛠️ Troubleshooting

### WiFi Not Connecting

```bash
# Check NetworkManager status
systemctl status NetworkManager

# Check connections
nmcli connection show

# Check if password was injected
sudo cat /etc/NetworkManager/system-connections/Home.nmconnection
# Should contain: psk=YourActualPassword

# Manual reload
sudo systemctl reload NetworkManager
```

### Secrets Not Decrypting

```bash
# Verify age key
ls -la /var/lib/sops-nix/key.txt
sudo age-keygen -y /var/lib/sops-nix/key.txt

# Test manual decryption
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops -d ~/nixos/secrets/wifi.yaml

# Check if key is in .sops.yaml
cat ~/nixos/.sops.yaml | grep -A5 "wifi"
```

### Password Not Injected

```bash
# Run activation script manually
sudo /nix/var/nix/profiles/system/activate

# Check if secret exists
ls -la /run/secrets/

# Verify secret content
sudo cat /run/secrets/wifi/home-psk
```

### Priority Issues

```bash
# Check auto-connect priority
nmcli -f NAME,AUTOCONNECT,AUTOCONNECT-PRIORITY connection show

# Adjust priority (higher = preferred)
nmcli connection modify "Home" connection.autoconnect-priority 100
nmcli connection modify "Work" connection.autoconnect-priority 50
```

---

## 📊 Network Priority

By default:

| Network | Priority | Behavior |
|---------|----------|----------|
| Home | 100 | **Always preferred** when in range |
| Work | 50 | Connect if Home not available |
| Parents | 30 | Lower priority |
| Ad-hoc | 0 | Manual/one-time only |

---

## 🔄 Removing Permanent Network

### Example: Remove "Parents" network

1. **Remove from `modules/system/wifi.nix`**:
   - Delete `sops.secrets."wifi/parents-psk"` section
   - Delete `environment.etc."NetworkManager/system-connections/Parents.nmconnection"` section
   - Delete password injection in `activationScripts`

2. **Optionally remove from secrets** (or keep for future use):
   ```bash
   sops secrets/wifi.yaml
   # Remove: wifi/parents-psk: ...
   ```

3. **Deploy**:
   ```bash
   git commit -am "Remove: Parents WiFi network"
   git push
   sudo nixos-rebuild switch --flake ~/nixos#hostname
   ```

---

## 🌐 Advanced: WPA2 Enterprise (eduroam)

```nix
environment.etc."NetworkManager/system-connections/Eduroam.nmconnection" = {
  mode = "0600";
  text = ''
    [connection]
    id=eduroam
    type=wifi
    autoconnect=false

    [wifi]
    ssid=eduroam

    [wifi-security]
    key-mgmt=wpa-eap

    [802-1x]
    eap=peap
    identity=student@university.edu
    phase2-auth=mschapv2
    password-flags=0

    [ipv4]
    method=auto
  '';
};

# Password injection for eduroam
sops.secrets."wifi/eduroam-password" = { /* ... */ };
```

---

## ✅ Summary

**Setup once:**
1. Create `secrets/wifi.yaml` with passwords
2. Update `modules/system/wifi.nix` with SSIDs
3. Enable module in `flake.nix`
4. Deploy to all hosts

**Daily use:**
- Permanent networks: **Auto-connect**
- Ad-hoc networks: `wifi-connect "SSID" password "pass"`

**All passwords**: 🔒 **Encrypted in git**
