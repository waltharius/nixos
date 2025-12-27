# Post-Installation SOPS Setup Guide

## 🔐 Setting up sops-nix After NixOS Installation

This guide helps you configure sops-nix secrets management **after** your NixOS system is installed and booted.

---

## Why This is Needed

**The Chicken-Egg Problem:**
- sops-nix needs **age public keys** to encrypt secrets
- Age keys are derived from **SSH host keys**
- SSH host keys are generated **during NixOS installation**
- Therefore: You can only setup sops **after** installation!

**Current Status:**
- ✅ Your `wifi.env` and `ssh.yaml` are encrypted with **placeholder keys**
- ❌ Your system can't decrypt them yet (different host keys)
- 🎯 Solution: Generate real keys and re-encrypt

---

## Step 1: Get Age Public Key from SSH Host Key

```bash
# SSH into your NixOS system (or use local terminal)
ssh marcin@sukkub

# Install ssh-to-age tool temporarily
nix-shell -p ssh-to-age

# Convert SSH host key to age public key
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# Output will be something like:
# age1xyz...abc123  ← THIS IS YOUR SUKKUB PUBLIC KEY!

# Save this key! You'll need it in the next step.
```

**Example output:**
```
age1t73dnh9pj2qsz3rfqgq54t2pyxh8ew6w8xsta7pfwmmxmsjswgrshue8gx
```

---

## Step 2: Update .sops.yaml with Real Keys

Edit `.sops.yaml` in your repo:

```bash
cd ~/nixos
vim .sops.yaml
```

**Replace the placeholder keys:**

```yaml
keys:
  # Admin key - your personal key (generate if you don't have one)
  - &admin age1YOUR_ADMIN_KEY_HERE
  
  # Host: sukkub - REPLACE WITH YOUR REAL KEY FROM STEP 1!
  - &sukkub age1t73dnh9pj2qsz3rfqgq54t2pyxh8ew6w8xsta7pfwmmxmsjswgrshue8gx
  
  # Host: azazel - Generate when you install second machine
  - &azazel age1PLACEHOLDER_FOR_SECOND_MACHINE

creation_rules:
  # ... rest stays the same
```

**Save the file.**

---

## Step 3: Re-encrypt All Secrets

After updating `.sops.yaml`, you need to **re-encrypt** all secrets with the new keys:

```bash
cd ~/nixos

# Install sops temporarily
nix-shell -p sops

# Re-encrypt wifi.env (IMPORTANT: Do this in the DECRYPTED state!)
# Option A: Edit and save (will re-encrypt automatically)
sops secrets/wifi.env
# Just save without changes (Ctrl+X or :wq)

# Option B: Use updatekeys command
sops updatekeys secrets/wifi.env

# Do the same for ssh.yaml
sops updatekeys secrets/ssh.yaml

# Verify encryption worked:
head -n 3 secrets/wifi.env
# Should show: HEGEMONIA5G-1=ENC[...]
```

---

## Step 4: Generate Admin Key (Optional but Recommended)

**Why?** So you can edit secrets from your laptop/desktop, not just on the NixOS machine.

```bash
# On your LAPTOP/WORKSTATION (not NixOS):
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# View your public key:
age-keygen -y ~/.config/sops/age/keys.txt

# Output:
# age1abc...xyz  ← YOUR ADMIN PUBLIC KEY

# Add this to .sops.yaml as &admin
# Then re-encrypt secrets (Step 3)
```

---

## Step 5: Commit and Rebuild

```bash
cd ~/nixos

# Add re-encrypted files
git add .sops.yaml secrets/wifi.env secrets/ssh.yaml

# Commit
git commit -m "feat: Update sops keys with real host keys"

# Push to GitHub
git push

# Rebuild NixOS
sudo nixos-rebuild switch --flake .#sukkub

# Check if secrets are decrypted:
ls -l /run/secrets/
# Should show: wifi-env-file

# Test decryption:
sudo cat /run/secrets/wifi-env-file
# Should show plain text WiFi passwords!
```

---

## Step 6: Verify WiFi Works

```bash
# Check WiFi status
nmcli device wifi list

# Check if your networks are configured
nmcli connection show

# Should see:
# Home      uuid-here  wifi  --
# Work      uuid-here  wifi  --
# Parents   uuid-here  wifi  --

# Test connection (should auto-connect on boot)
sudo systemctl restart NetworkManager
```

---

## Troubleshooting

### ❌ Error: "failed to get the data key"

**Cause:** Secret was encrypted with different age key than what your system has.

**Fix:**
```bash
# 1. Get your REAL age public key (Step 1)
# 2. Update .sops.yaml with it (Step 2)
# 3. Re-encrypt secrets (Step 3)
```

### ❌ Error: "attribute 'wifi-env-file' missing"

**Cause:** Old configuration cached.

**Fix:**
```bash
cd ~/nixos
git pull  # Get latest fixes
sudo nixos-rebuild switch --flake .#sukkub
```

### ❌ WiFi networks show but don't connect

**Cause:** Passwords not injected properly.

**Fix:**
```bash
# Check if secret file exists and is decrypted:
sudo cat /run/secrets/wifi-env-file

# Should show:
# HEGEMONIA5G_1=YourPassword
# HEGEMONIA5G_2=YourPassword
# SALON_NEW24=YourPassword

# If file is missing or encrypted, rebuild:
sudo nixos-rebuild switch --flake .#sukkub
```

### ❌ Error: "No such file or directory: /var/lib/sops-nix/key.txt"

**Cause:** Old secrets.nix configuration.

**Fix:** Already fixed in latest commit! Just rebuild:
```bash
cd ~/nixos
git pull
sudo nixos-rebuild switch --flake .#sukkub
```

---

## Security Notes

### ✅ Safe to Commit (Public):
- `.sops.yaml` - Contains **public** age keys only
- `secrets/*.env` - Encrypted files (useless without private key)
- `secrets/*.yaml` - Encrypted files

### ❌ NEVER COMMIT (Private):
- `/etc/ssh/ssh_host_*_key` - SSH private keys (on NixOS)
- `/var/lib/sops-nix/key.txt` - Age private key (auto-generated)
- `~/.config/sops/age/keys.txt` - Your admin private key (on laptop)
- `secrets/*.dec` - Decrypted files
- `secrets/*.yaml.dec` - Decrypted files

---

## Adding a Second Machine (azazel)

```bash
# 1. Install NixOS on second machine
# 2. Boot and SSH in
# 3. Get age public key:
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# 4. Add to .sops.yaml:
- &azazel age1YOUR_NEW_KEY_HERE

# 5. Re-encrypt all secrets:
sops updatekeys secrets/*.env secrets/*.yaml

# 6. Commit and push:
git add .sops.yaml secrets/
git commit -m "feat: Add azazel host key"
git push

# 7. On azazel, rebuild:
sudo nixos-rebuild switch --flake .#azazel
```

---

## Quick Reference

```bash
# Get age public key from SSH key:
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# Edit encrypted secret:
sops secrets/wifi.env

# Re-encrypt after .sops.yaml change:
sops updatekeys secrets/wifi.env

# Check decrypted secrets:
ls -l /run/secrets/
sudo cat /run/secrets/wifi-env-file

# Rebuild system:
sudo nixos-rebuild switch --flake .#sukkub
```

---

## Summary

**What you need to do NOW:**

1. ✅ Get your real age public key from sukkub
2. ✅ Update `.sops.yaml` with it
3. ✅ Re-encrypt `wifi.env` and `ssh.yaml`
4. ✅ Commit and push
5. ✅ Rebuild NixOS
6. ✅ WiFi should work automatically!

**Total time: 5-10 minutes** ⏱️
