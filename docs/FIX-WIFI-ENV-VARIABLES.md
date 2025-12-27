# 🔧 URGENT: Fix WiFi Environment Variable Names

## Problem

Your `secrets/wifi.env` has **invalid variable names** with dashes (`-`) which are not allowed in dotenv format:

```bash
❌ HEGEMONIA5G-1=...  # INVALID - dash not allowed
❌ HEGEMONIA5G-2=...  # INVALID - dash not allowed  
✅ SALON_NEW24=...    # VALID - underscore is OK
```

**Error message you see:**
```
error: Cannot build manifest.json
Reason: cannot parse dotenv: unexpected character "-" in variable name
```

---

## Solution: Rename Variables

Change dashes to underscores:

```bash
HEGEMONIA5G-1  →  HEGEMONIA5G_1
HEGEMONIA5G-2  →  HEGEMONIA5G_2
```

---

## Step-by-Step Fix

### 1. Pull Latest Changes

```bash
cd ~/nixos
git pull
```

### 2. Decrypt wifi.env

```bash
cd ~/nixos

# Install sops temporarily
nix-shell -p sops

# Decrypt to plain text
sops -d secrets/wifi.env > /tmp/wifi.env.plain

# View decrypted content
cat /tmp/wifi.env.plain

# Output will be something like:
# HEGEMONIA5G-1=YourPassword1
# HEGEMONIA5G-2=YourPassword2
# SALON_NEW24=YourPassword3
```

### 3. Edit Variable Names

```bash
# Edit the decrypted file
vim /tmp/wifi.env.plain

# Change:
# HEGEMONIA5G-1=YourPassword1
# HEGEMONIA5G-2=YourPassword2
#
# To:
# HEGEMONIA5G_1=YourPassword1
# HEGEMONIA5G_2=YourPassword2
#
# Leave SALON_NEW24 as is (already has underscore)

# Save and exit (:wq)
```

### 4. Re-encrypt with Corrected Names

```bash
# Backup original (just in case)
cp secrets/wifi.env secrets/wifi.env.backup

# Encrypt the corrected file
sops -e /tmp/wifi.env.plain > secrets/wifi.env

# Verify encryption worked
head -n 3 secrets/wifi.env
# Should show: HEGEMONIA5G_1=ENC[...]
#              HEGEMONIA5G_2=ENC[...]
```

### 5. Clean Up Temporary Files

```bash
# IMPORTANT: Delete plain text file!
shred -u /tmp/wifi.env.plain

# Or if shred not available:
rm -f /tmp/wifi.env.plain
```

### 6. Commit Changes

```bash
cd ~/nixos

# Stage the fixed file
git add secrets/wifi.env

# Commit
git commit -m "fix: Use underscores in wifi.env variable names (dotenv compliance)"

# Push
git push
```

### 7. Rebuild NixOS

```bash
# Rebuild with fixed configuration
sudo nixos-rebuild switch --flake .#sukkub

# Should now build successfully! ✅
```

### 8. Verify WiFi Works

```bash
# Check secrets are decrypted
ls -l /run/secrets/wifi-env-file

# View decrypted content (should show underscores now)
sudo cat /run/secrets/wifi-env-file

# Expected output:
# HEGEMONIA5G_1=YourPassword1
# HEGEMONIA5G_2=YourPassword2
# SALON_NEW24=YourPassword3

# Check WiFi connections
nmcli connection show
# Should list: Home, Work, Parents

# Restart NetworkManager
sudo systemctl restart NetworkManager

# WiFi should auto-connect!
```

---

## Alternative: Edit in-place with sops

```bash
cd ~/nixos

# Open encrypted file in editor
sops secrets/wifi.env

# Edit directly:
# Change HEGEMONIA5G-1 to HEGEMONIA5G_1
# Change HEGEMONIA5G-2 to HEGEMONIA5G_2

# Save and exit (file auto-encrypts)

# Commit and rebuild
git add secrets/wifi.env
git commit -m "fix: wifi.env variable names"
git push
sudo nixos-rebuild switch --flake .#sukkub
```

---

## Why This Happened

**Dotenv format rules:**
- Variable names can contain: `A-Z`, `a-z`, `0-9`, `_` (underscore)
- Variable names CANNOT contain: `-` (dash), spaces, special chars
- This is POSIX shell variable naming convention

**Your original names:**
```bash
HEGEMONIA5G-1  # ❌ Dash treated as minus operator
HEGEMONIA5G_1  # ✅ Underscore is valid identifier
```

---

## Security Note

⚠️ **ALWAYS delete plain text temporary files after encryption!**

```bash
# Good:
shred -u /tmp/wifi.env.plain

# Or:
rm -f /tmp/wifi.env.plain
```

Never commit `.dec` or plain text password files to git!

---

## Quick Command Summary

```bash
# 1. Pull changes
cd ~/nixos && git pull

# 2. Edit wifi.env (in-place)
nix-shell -p sops --run "sops secrets/wifi.env"
# Change dashes to underscores, save

# 3. Commit and rebuild
git add secrets/wifi.env
git commit -m "fix: wifi.env variable names"
git push
sudo nixos-rebuild switch --flake .#sukkub

# 4. Verify
sudo cat /run/secrets/wifi-env-file
nmcli connection show
```

---

## Expected Result

✅ NixOS rebuild succeeds without dotenv parse errors
✅ WiFi secrets are decrypted to `/run/secrets/wifi-env-file`
✅ NetworkManager profiles get passwords injected
✅ WiFi auto-connects on boot

**Total time: 2-3 minutes** ⏱️
