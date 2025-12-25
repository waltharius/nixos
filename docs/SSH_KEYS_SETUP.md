# SSH Keys Setup Guide

This guide explains how to configure SSH keys with SOPS encryption in your NixOS configuration.

## Overview

SSH keys are stored encrypted in `secrets/ssh.yaml` using SOPS (Secrets OPerationS) with age encryption.

## Prerequisites

1. Age key generated during installation at `/var/lib/sops-nix/key.txt`
2. SOPS installed on your management machine (Fedora)
3. SSH keys you want to migrate

## Step 1: Get Your Public Age Keys

### On Sukkub (after installation):

```bash
# Show public age key
sudo age-keygen -y /var/lib/sops-nix/key.txt
# Output: age1qqc8xq7z9m2...

# SAVE THIS KEY! You'll need it for .sops.yaml
```

### On Your Management Machine (Fedora):

```bash
# If you don't have age key yet:
age-keygen -o ~/.config/sops/age/keys.txt

# Show your public key:
age-keygen -y ~/.config/sops/age/keys.txt
```

## Step 2: Update .sops.yaml

Edit `.sops.yaml` in your repo with REAL public keys:

```yaml
keys:
  # Your personal key (for managing secrets from Fedora)
  - &admin age1qqc8xq7z9m2...YOUR_FEDORA_KEY
  
  # Sukkub host key (from Step 1)
  - &sukkub age1xxx...REAL_SUKKUB_KEY
  
  # Azazel host key (generate later)
  - &azazel age1yyy...REAL_AZAZEL_KEY

creation_rules:
  - path_regex: secrets/ssh\.yaml$
    key_groups:
      - age:
          - *admin
          - *sukkub
          - *azazel
```

## Step 3: Prepare Your SSH Keys

### Generate New Keys (Recommended)

```bash
# GitHub key
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_github

# GitLab key
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_gitlab

# Tabby/Server access key
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_tabby
```

### OR Copy Existing Keys

```bash
# Copy your existing keys
cp ~/old_ssh/id_ed25519 ~/.ssh/id_ed25519_github
cp ~/old_ssh/id_ed25519.pub ~/.ssh/id_ed25519_github.pub
```

## Step 4: Add Public Key to GitHub/GitLab

```bash
# Copy public key
cat ~/.ssh/id_ed25519_github.pub

# Add to:
# GitHub: https://github.com/settings/keys
# GitLab: https://gitlab.com/-/profile/keys
```

## Step 5: Create secrets/ssh.yaml

### Initial Creation:

```bash
cd ~/nixos

# Create encrypted file
sops secrets/ssh.yaml
```

SOPS will open your editor. Add your keys in this format:

```yaml
# Private SSH keys
ssh_key_github: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
  ... (your full private key content) ...
  -----END OPENSSH PRIVATE KEY-----

ssh_key_gitlab: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ... (gitlab private key) ...
  -----END OPENSSH PRIVATE KEY-----

ssh_key_tabby: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ... (tabby private key) ...
  -----END OPENSSH PRIVATE KEY-----

# SSH config for hosts
ssh_config: |
  # Personal server
  Host myserver
    HostName 192.168.1.100
    User marcin
    Port 22
    IdentityFile ~/.ssh/id_ed25519_tabby
  
  # Another host
  Host backup
    HostName backup.example.com
    User admin
    Port 2222
```

### To Get Private Key Content:

```bash
# Show private key (will copy to clipboard)
cat ~/.ssh/id_ed25519_github

# Or copy directly:
xclip -sel clip < ~/.ssh/id_ed25519_github  # Linux
pbcopy < ~/.ssh/id_ed25519_github           # macOS
```

## Step 6: Re-encrypt for All Hosts

After updating `.sops.yaml` with real keys:

```bash
# This re-encrypts the file for all keys in .sops.yaml
sops updatekeys secrets/ssh.yaml

# Verify it works
sops -d secrets/ssh.yaml
# Should show decrypted content
```

## Step 7: Commit and Push

```bash
git add .sops.yaml secrets/ssh.yaml
git commit -m "Update: Real age keys and SSH secrets"
git push
```

## Step 8: Deploy on Sukkub

```bash
# On Sukkub
cd ~/nixos
sudo git pull

# Test decryption
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops -d secrets/ssh.yaml
# Should show your keys!

# Rebuild
sudo nixos-rebuild switch --flake ~/nixos#sukkub

# Check SSH keys
ls -la ~/.ssh/
# Should see: id_ed25519_github, id_ed25519_gitlab, id_ed25519_tabby

# Test GitHub
ssh -T git@github.com
# Output: Hi username! You've successfully authenticated...
```

## Adding SSH Server Access (Remote Login)

### Get Your Tabby Public Key

On your client machine (where you want to SSH FROM):

```bash
cat ~/.ssh/id_ed25519_tabby.pub
# Copy the output: ssh-ed25519 AAAAC3...
```

### Add to configuration.nix

Edit `hosts/sukkub/configuration.nix`:

```nix
users.users.marcin = {
  isNormalUser = true;
  extraGroups = [ "networkmanager" "wheel" ];
  
  # PASTE YOUR PUBLIC KEY HERE:
  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbCdEf... marcin@tabby"
  ];
};
```

### Deploy and Test

```bash
# On Sukkub
sudo nixos-rebuild switch --flake ~/nixos#sukkub

# From another machine
ssh -i ~/.ssh/id_ed25519_tabby marcin@sukkub.local
# Should login WITHOUT password!
```

## Troubleshooting

### "no key could decrypt the data"

```bash
# Check your age key
age-keygen -y /var/lib/sops-nix/key.txt

# Verify it matches .sops.yaml
cat .sops.yaml | grep age1

# If different, update .sops.yaml and re-encrypt
sops updatekeys secrets/ssh.yaml
```

### SSH keys not appearing in ~/.ssh/

```bash
# Check sops-nix logs
journalctl -u home-manager-marcin.service

# Verify sops config in home.nix
cat ~/nixos/users/marcin/home.nix | grep -A5 "sops ="

# Manual test
sudo -u marcin SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
  sops -d ~/nixos/secrets/ssh.yaml
```

### Permission denied (publickey)

```bash
# Check key permissions
ls -la ~/.ssh/id_ed25519_*
# Should be: -rw------- (600)

# Check if key is loaded
ssh-add -l

# Test with verbose
ssh -vT git@github.com
```

## Security Notes

1. **NEVER commit unencrypted private keys** to git
2. **Backup your age keys** - store in password manager
3. **Use different keys** for different services (defense in depth)
4. **Rotate keys** if compromised
5. **secrets/ssh.yaml is SAFE to commit** - it's encrypted

## Key Rotation

If you need to change keys:

```bash
# 1. Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github_new

# 2. Add public key to GitHub
cat ~/.ssh/id_ed25519_github_new.pub
# Add at: https://github.com/settings/keys

# 3. Update secrets/ssh.yaml
sops secrets/ssh.yaml
# Replace old key with new

# 4. Deploy
git add secrets/ssh.yaml
git commit -m "Rotate: GitHub SSH key"
git push

# 5. On all hosts
sudo nixos-rebuild switch --flake ~/nixos#hostname

# 6. Remove old key from GitHub
```

## Next Steps

- Set up SSH config for your personal servers
- Configure SSH agent forwarding if needed
- Add more hosts to your NixOS fleet
- Consider hardware tokens (YubiKey) for extra security
