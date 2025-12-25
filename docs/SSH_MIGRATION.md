# SSH Keys and Config Migration Guide

This guide explains how to securely migrate your SSH keys and configuration from Fedora to NixOS using sops-nix encryption.

## Overview

**Goal:** Transfer SSH private keys and host configuration from Fedora, encrypt them with sops-nix, and make them available on both sukkub and azazel.

**Security Model:**
- SSH keys stored as encrypted secrets in repo
- Each host can decrypt only with its age private key
- Both sukkub and azazel can decrypt (both keys in `.sops.yaml`)
- Git repo remains safe even if published

## Step-by-Step Process

### Phase 1: Preparation on Fedora (Current System)

#### 1. Backup Current SSH Configuration

```bash
# On Fedora
cd ~
mkdir -p ssh-backup

# Copy private keys
cp ~/.ssh/id_ed25519_github ssh-backup/
cp ~/.ssh/id_ed25519_tabby ssh-backup/

# Copy host configuration
cp ~/.ssh/config ssh-backup/ssh_config
# Or if you have it in config.d:
cp ~/.ssh/config.d/hosts ssh-backup/ssh_hosts

# Verify files
ls -la ssh-backup/
```

#### 2. Install SOPS and Age on Fedora (if not installed)

```bash
# On Fedora
sudo dnf install age sops

# Or use nix-shell temporarily
nix-shell -p age sops
```

### Phase 2: Setup on Sukkub (First NixOS Host)

#### 3. Generate Age Key on Sukkub

During installation (from installation guide):

```bash
# On sukkub (during or after installation)
mkdir -p /var/lib/sops-nix
age-keygen -o /var/lib/sops-nix/key.txt

# Get public key - SAVE THIS!
age-keygen -y /var/lib/sops-nix/key.txt
# Example output: age1qqq...xyz
```

#### 4. Copy Sukkub Public Key to Your Management Machine

```bash
# On sukkub
age-keygen -y /var/lib/sops-nix/key.txt > /tmp/sukkub_age_public.key

# Transfer to Fedora (choose one method):
# Via USB stick:
cp /tmp/sukkub_age_public.key /media/usb/

# Via network (if SSH is set up):
scp /tmp/sukkub_age_public.key user@fedora-machine:/tmp/

# Or just copy-paste the output manually
```

### Phase 3: Create Encrypted Secrets on Fedora

#### 5. Setup Personal Age Key on Fedora

```bash
# On Fedora
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Get your personal public key
age-keygen -y ~/.config/sops/age/keys.txt
# Example output: age1xxx...abc
```

#### 6. Clone NixOS Repo and Update `.sops.yaml`

```bash
# On Fedora
cd ~/
git clone https://github.com/waltharius/nixos.git
cd nixos

# Edit .sops.yaml
vim .sops.yaml
```

Replace placeholders with actual public keys:

```yaml
keys:
  - &admin age1xxx...abc              # Your personal key from step 5
  - &sukkub age1qqq...xyz             # Sukkub key from step 4
  - &azazel WILL_ADD_LATER            # Will generate when installing azazel

creation_rules:
  # SSH secrets - shared between hosts
  - path_regex: secrets/ssh\.yaml$
    key_groups:
      - age:
          - *admin
          - *sukkub
          - *azazel
  
  # ... rest of creation_rules ...
```

#### 7. Create Encrypted SSH Secrets File

```bash
# On Fedora, in nixos repo directory
cd ~/nixos

# Create secrets/ssh.yaml with sops
sops secrets/ssh.yaml
```

This opens your `$EDITOR`. Add your SSH data in YAML format:

```yaml
# SSH private keys (paste entire key including headers)
ssh_key_github: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
  ... (rest of your GitHub key) ...
  -----END OPENSSH PRIVATE KEY-----

ssh_key_tabby: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ... (your Tabby key) ...
  -----END OPENSSH PRIVATE KEY-----

# SSH host configuration
ssh_config: |
  # Your SSH hosts from ~/.ssh/config.d/hosts
  Host myserver
    HostName 192.168.1.100
    User admin
    Port 22
  
  Host another-host
    HostName server.example.com
    User marcin
```

**Important:**
- Use `|` for multiline strings in YAML
- Include complete key files with BEGIN/END markers
- Indentation matters in YAML

Save and exit. SOPS will automatically encrypt the file.

#### 8. Verify Encryption

```bash
# File should be encrypted
cat secrets/ssh.yaml
# Should see: sops:
#              kms: []
#              gcp_kms: []
#              ...

# Decrypt to verify (doesn't save to disk)
sops -d secrets/ssh.yaml
# Should show your keys in plaintext
```

#### 9. Commit and Push

```bash
# On Fedora
git add .sops.yaml secrets/ssh.yaml
git commit -m "Add encrypted SSH keys and configuration"
git push
```

### Phase 4: Use on Sukkub

#### 10. Pull Repo on Sukkub

```bash
# On sukkub
cd /etc/nixos
git pull
```

#### 11. Test Decryption

```bash
# On sukkub
cd /etc/nixos

# Verify age key exists
ls -la /var/lib/sops-nix/key.txt

# Test decryption
export SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt
sops -d secrets/ssh.yaml

# Should show your SSH keys in plaintext
```

#### 12. Rebuild System

```bash
# On sukkub
sudo nixos-rebuild switch --flake /etc/nixos#sukkub
```

Home-manager will:
- Decrypt `secrets/ssh.yaml`
- Place keys in `~/.ssh/id_ed25519_github` and `~/.ssh/id_ed25519_tabby`
- Place config in `~/.ssh/config.d/hosts`
- Set correct permissions (0600)

#### 13. Verify SSH Works

```bash
# Check files exist
ls -la ~/.ssh/

# Test GitHub connection
ssh -T git@github.com
# Should see: Hi waltharius! You've successfully authenticated...

# Test host from config
ssh myserver
```

### Phase 5: Setup Azazel (When Ready)

#### 14. Generate Age Key on Azazel

```bash
# On azazel (during installation)
mkdir -p /var/lib/sops-nix
age-keygen -o /var/lib/sops-nix/key.txt
age-keygen -y /var/lib/sops-nix/key.txt
# Save this public key!
```

#### 15. Update `.sops.yaml` with Azazel Key

```bash
# On your management machine (Fedora or sukkub)
cd ~/nixos
vim .sops.yaml
```

Add azazel's public key:

```yaml
keys:
  - &admin age1xxx...abc
  - &sukkub age1qqq...xyz
  - &azazel age1zzz...def    # Add azazel's public key here
```

#### 16. Re-encrypt All Secrets

```bash
# On management machine
sops updatekeys secrets/ssh.yaml
sops updatekeys secrets/common.yaml
# ... for any other secret files

git add .sops.yaml secrets/
git commit -m "Add azazel to SSH secrets"
git push
```

#### 17. Use on Azazel

```bash
# On azazel
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake /etc/nixos#azazel

# Verify
ssh -T git@github.com
```

## Security Best Practices

### ✅ Safe to Commit

- `.sops.yaml` with **public keys only**
- `secrets/*.yaml` **encrypted files**
- All Nix configuration files

### ❌ NEVER Commit

- Age **private keys** (`keys.txt`, `/var/lib/sops-nix/key.txt`)
- Decrypted secret files (`*.dec`)
- Plaintext SSH keys outside of encrypted secrets

### Backup Strategy

**Critical to backup:**
1. `~/.config/sops/age/keys.txt` (your personal key)
2. `/var/lib/sops-nix/key.txt` from each host

**How to backup:**
```bash
# Create encrypted backup
tar czf age-keys-backup.tar.gz \
  ~/.config/sops/age/keys.txt \
  /var/lib/sops-nix/key.txt

# Encrypt with GPG
gpg -c age-keys-backup.tar.gz

# Store in safe location (password manager, encrypted USB, cloud)
```

**To restore:**
```bash
# Decrypt
gpg -d age-keys-backup.tar.gz.gpg > age-keys-backup.tar.gz

# Extract
tar xzf age-keys-backup.tar.gz

# Restore keys
mkdir -p ~/.config/sops/age
cp keys.txt ~/.config/sops/age/
chmod 600 ~/.config/sops/age/keys.txt
```

## Troubleshooting

### Cannot Decrypt on Host

**Problem:** `sops -d secrets/ssh.yaml` fails

**Check:**
1. Age key exists: `ls -la /var/lib/sops-nix/key.txt`
2. Public key is in `.sops.yaml`
3. Secrets were re-encrypted after adding host: `sops updatekeys secrets/ssh.yaml`

### SSH Keys Not Working

**Problem:** `ssh -T git@github.com` fails

**Check:**
1. Files exist: `ls -la ~/.ssh/id_ed25519_*`
2. Permissions: `ls -l ~/.ssh/id_ed25519_github` (should be `-rw-------`)
3. ssh-agent: `ssh-add -l`
4. Config: `cat ~/.ssh/config.d/hosts`

### Wrong Permissions After Rebuild

**Problem:** SSH complains about permissions

**Fix:**
```bash
chmod 600 ~/.ssh/id_ed25519_*
chmod 600 ~/.ssh/config.d/hosts
```

(This shouldn't happen - sops-nix sets mode = "0600", but if it does...)

## Adding New SSH Keys Later

```bash
# Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_newhost

# Edit encrypted secrets
sops secrets/ssh.yaml

# Add new key:
ssh_key_newhost: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ... paste key content ...
  -----END OPENSSH PRIVATE KEY-----

# Update SSH module to include new key
vim modules/services/ssh.nix
```

Add to `sops.secrets`:

```nix
ssh_key_newhost = {
  sopsFile = ../../secrets/ssh.yaml;
  path = "${config.home.homeDirectory}/.ssh/id_ed25519_newhost";
  mode = "0600";
};
```

## Reference

- [sops-nix Documentation](https://github.com/Mic92/sops-nix)
- [age Encryption](https://github.com/FiloSottile/age)
- [OpenSSH Configuration](https://www.openssh.com/manual.html)
