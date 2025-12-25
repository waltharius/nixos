# NixOS Installation Guide

This guide will walk you through installing NixOS with this flake-based configuration.

## 🎯 Overview

This installation uses:
- **Flakes** for reproducible configuration
- **LUKS** full disk encryption
- **Btrfs** with subvolumes for flexibility
- **SOPS-nix** for secrets management
- **Home-manager** for user configuration
- **Configuration in ~/nixos** (not /etc/nixos) for easy git workflow

## 📋 Prerequisites

1. NixOS installer USB drive
2. Target machine (sukkub or azazel)
3. Internet connection
4. GitHub access for cloning repository

---

## 🚀 Installation Steps

### 1. Boot from USB

Boot your machine from the NixOS installer USB.

### 2. Set up networking (if needed)

```bash
# For WiFi
sudo systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "YourSSID"
> set_network 0 psk "YourPassword"
> enable_network 0
> quit

# Test connection
ping -c 3 1.1.1.1
```

### 3. Partition the disk

**⚠️ WARNING: This will ERASE ALL DATA on the target disk!**

```bash
# Identify your disk (usually /dev/nvme0n1 or /dev/sda)
lsblk

# For this guide, we'll use /dev/nvme0n1
# Replace with your actual disk
DISK="/dev/nvme0n1"

# Create GPT partition table
parted $DISK -- mklabel gpt

# Create EFI boot partition (512MB)
parted $DISK -- mkpart ESP fat32 1MiB 512MiB
parted $DISK -- set 1 esp on

# Create root partition (rest of disk)
parted $DISK -- mkpart primary 512MiB 100%

# Verify
parted $DISK -- print
```

### 4. Set up LUKS encryption

```bash
# Encrypt the root partition
cryptsetup luksFormat ${DISK}p2
# Enter a STRONG passphrase - you'll need this on every boot!
# WRITE IT DOWN SECURELY!

# Open the encrypted partition
cryptsetup open ${DISK}p2 cryptroot
```

### 5. Create filesystems

```bash
# Format EFI partition
mkfs.fat -F32 -n BOOT ${DISK}p1

# Format root with btrfs
mkfs.btrfs -L nixos /dev/mapper/cryptroot

# Mount root temporarily to create subvolumes
mount /dev/mapper/cryptroot /mnt

# Create btrfs subvolumes
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
btrfs subvolume create /mnt/persist
btrfs subvolume create /mnt/log

# Unmount
umount /mnt
```

### 6. Mount filesystems

```bash
# Mount root subvolume with optimized options
mount -o subvol=root,compress=zstd,noatime /dev/mapper/cryptroot /mnt

# Create mount points
mkdir -p /mnt/{home,nix,persist,var/log,boot}

# Mount other subvolumes
mount -o subvol=home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home
mount -o subvol=nix,compress=zstd,noatime /dev/mapper/cryptroot /mnt/nix
mount -o subvol=persist,compress=zstd,noatime /dev/mapper/cryptroot /mnt/persist
mount -o subvol=log,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/log

# Mount boot partition
mount ${DISK}p1 /mnt/boot

# Verify mounts
mount | grep /mnt
```

### 7. Clone configuration repository

```bash
# Create user home directory structure
mkdir -p /mnt/home/marcin

# Clone this repository to user's home (NOT /etc/nixos!)
cd /mnt/home/marcin
git clone https://github.com/waltharius/nixos.git

# Set ownership to marcin (UID 1000)
chown -R 1000:100 /mnt/home/marcin/nixos

# Create symlink for convenience
ln -s /mnt/home/marcin/nixos /mnt/etc/nixos
```

### 8. Generate hardware configuration

```bash
# Generate hardware-configuration.nix
nixos-generate-config --root /mnt --show-hardware-config > /mnt/home/marcin/nixos/hosts/sukkub/hardware-configuration.nix

# ⚠️ IMPORTANT: Edit hardware-configuration.nix to ensure LUKS is configured
vim /mnt/home/marcin/nixos/hosts/sukkub/hardware-configuration.nix

# Make sure these lines exist:
# boot.initrd.luks.devices."cryptroot" = {
#   device = "/dev/disk/by-uuid/YOUR-UUID-HERE";
#   preLVM = true;
# };
```

### 9. Generate SOPS age key

```bash
# Create directory for sops keys
mkdir -p /mnt/var/lib/sops-nix

# Generate age key for this host
age-keygen -o /mnt/var/lib/sops-nix/key.txt

# Set secure permissions
chmod 600 /mnt/var/lib/sops-nix/key.txt
chown 0:0 /mnt/var/lib/sops-nix/key.txt

# Display public key - SAVE THIS!
age-keygen -y /mnt/var/lib/sops-nix/key.txt
# Output: age1abc123...
# ⚠️ SAVE THIS PUBLIC KEY! You'll need it to update .sops.yaml
```

### 10. Add SSH public key (optional, for remote access)

```bash
# If you want to SSH into this machine, add your public key
vim /mnt/home/marcin/nixos/hosts/sukkub/configuration.nix

# Uncomment and replace with your actual public key:
# openssh.authorizedKeys.keys = [
#   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxx... marcin@tabby"
# ];
```

### 11. Install NixOS

```bash
# Install using the flake
nixos-install --flake /mnt/etc/nixos#sukkub --no-root-password

# This will take a while (downloading packages, building configuration)
# Watch for any errors
```

### 12. Fix bootloader random-seed permissions

```bash
# Fix permissions (security issue)
chmod 600 /mnt/boot/loader/random-seed

# Remove temporary files
rm -f /mnt/boot/loader/.#bootctl*
```

### 13. Set user password

```bash
# Enter chroot
nixos-enter --root /mnt

# Set password for marcin
passwd marcin
# Enter a strong password

# Exit chroot
exit
```

### 14. Reboot

```bash
# Unmount all filesystems
umount -R /mnt

# Reboot
reboot
```

**REMOVE THE USB DRIVE!**

---

## 🔐 Post-Installation Setup

### 1. First boot

1. Enter LUKS passphrase when prompted
2. Login as `marcin` with the password you set
3. System should boot into GNOME

### 2. Update .sops.yaml with real age key

**On your Fedora machine (or wherever you manage the repo):**

```bash
cd ~/nixos

# Edit .sops.yaml and add the real public key from step 9
vim .sops.yaml

# Change:
# keys:
#   - &sukkub age1xxx_PLACEHOLDER
# To:
#   - &sukkub age1abc123_REAL_KEY_FROM_STEP_9

# Re-encrypt secrets with the new key
sops updatekeys secrets/ssh.yaml

# Commit and push
git add .sops.yaml secrets/ssh.yaml
git commit -m "Add real sukkub age key"
git push
```

### 3. On sukkub: Pull changes and rebuild

```bash
# Pull updated configuration
cd ~/nixos
git pull

# Rebuild system
sudo nixos-rebuild switch --flake ~/nixos#sukkub

# SSH keys should now be decrypted to ~/.ssh/
ls -la ~/.ssh/
```

### 4. Test SSH keys

```bash
# Test GitHub
ssh -T git@github.com
# Should output: Hi waltharius! You've successfully authenticated...

# Test GitLab
ssh -T git@gitlab.com
# Should output: Welcome to GitLab...
```

### 5. Test remote SSH access (from another machine)

```bash
# From Fedora/another machine
ssh -i ~/.ssh/id_ed25519_tabby marcin@sukkub.local
# Should login without password!
```

---

## 🎯 Configuration Workflow

Now that installation is complete, your workflow is:

```bash
# 1. Edit configuration (no sudo needed!)
vim ~/nixos/users/marcin/home.nix

# 2. Commit changes
cd ~/nixos
git add .
git commit -m "Update config"
git push

# 3. Rebuild system (only this needs sudo)
sudo nixos-rebuild switch --flake ~/nixos#sukkub
```

---

## ⚠️ Important Notes

### Backups - Critical Data

**BACKUP THESE IMMEDIATELY:**

1. **LUKS passphrase** - Without this, you cannot boot or decrypt data!
2. **Age private key**: `/var/lib/sops-nix/key.txt` - Needed for secrets
3. **Age public key** - Needed to update .sops.yaml

```bash
# Backup age keys
sudo cat /var/lib/sops-nix/key.txt  # Private key - SECURE THIS!
age-keygen -y /var/lib/sops-nix/key.txt  # Public key
```

### Repository Structure

```
/home/marcin/nixos/           # Your git repository
├── flake.nix
├── hosts/
│   └── sukkub/
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── users/
│   └── marcin/
│       └── home.nix
├── modules/
└── secrets/

/etc/nixos -> /home/marcin/nixos  # Symlink for convenience

/var/lib/sops-nix/
└── key.txt                   # Age private key (root-only)
```

### Why ~/nixos instead of /etc/nixos?

**Benefits:**
- ✅ Edit files without sudo
- ✅ Git works normally (no "dubious ownership")
- ✅ Push/pull without permission issues
- ✅ Only `nixos-rebuild` needs sudo

---

## 🔧 Troubleshooting

### Installation fails with "no key could decrypt"

This is EXPECTED during initial installation. SSH keys won't work until you:
1. Update .sops.yaml with the real age key
2. Re-encrypt secrets
3. Pull and rebuild on sukkub

### Git shows "dubious ownership"

Make sure:
```bash
# Check ownership
ls -la ~/nixos
# Should show: marcin:users

# If not, fix it:
sudo chown -R marcin:users ~/nixos
```

### SSHD not starting

Check firewall:
```bash
# Verify port 22 is open
sudo nix-shell -p nmap --run "nmap -p 22 localhost"

# Check service status
systemctl status sshd
```

---

## 📚 Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [SOPS-nix Documentation](https://github.com/Mic92/sops-nix)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)

---

**Installation complete! Welcome to NixOS! 🎉**
