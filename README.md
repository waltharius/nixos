# Multi-Host NixOS Configuration

Declarative, reproducible NixOS configuration for multiple hosts using flakes, home-manager, and sops-nix.

## 🚀 Quick Start

**For full documentation, see [README.org](README.org)**

### Hosts

- **sukkub**: ThinkPad P50 (test/POC, no battery)
- **azazel**: ThinkPad T16 Gen3 (production, 128GB RAM, hibernate support)

### Key Features

- ✅ Multi-host configuration with shared modules
- ✅ Btrfs with zstd:3 compression
- ✅ Home-manager for user configuration
- ✅ Sops-nix for encrypted secrets
- ✅ Suspend-then-hibernate (azazel)
- ✅ Full Neovim setup with LSP (nixd, lua_ls)
- ✅ Reproducible with flake.lock

## 📦 Installation (Brief)

1. Boot NixOS 25.11 ISO
2. Partition disk with btrfs (see [README.org](README.org) for details)
3. Clone repo:
   ```bash
   git clone https://github.com/waltharius/nixos.git /mnt/etc/nixos
   ```
4. Generate hardware config:
   ```bash
   nixos-generate-config --root /mnt
   cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/sukkub/
   ```
5. Generate age key:
   ```bash
   mkdir -p /mnt/var/lib/sops-nix
   age-keygen -o /mnt/var/lib/sops-nix/key.txt
   age-keygen -y /mnt/var/lib/sops-nix/key.txt  # Save this public key!
   ```
6. Install:
   ```bash
   nixos-install --flake /mnt/etc/nixos#sukkub
   ```

## 🔐 Secrets Management

**Safe to commit:**
- ✅ Public keys in `.sops.yaml`
- ✅ Encrypted `*.yaml` files in `secrets/`

**Never commit:**
- ❌ Private keys (`keys.txt`, `*.key`)
- ❌ Decrypted files (`*.dec`)

See [README.org](README.org#secrets-management-with-sops) for complete guide.

## 📖 Documentation

See **[README.org](README.org)** for:
- Complete installation guide with btrfs setup
- Secrets management workflow
- Daily usage (rebuild, update, rollback)
- Laptop features (TLP, hibernate)
- Troubleshooting
- Customization guide

## 🛠️ Daily Commands

```bash
# Rebuild system
sudo nixos-rebuild switch --flake /etc/nixos#sukkub

# Update packages
nix flake update

# Rollback
sudo nixos-rebuild switch --rollback

# Edit secrets
sops secrets/common.yaml
```

## 📂 Repository Structure

```
nixos/
├── flake.nix              # Main configuration
├── .sops.yaml             # Public keys (safe)
├── hosts/                 # Per-host configs
│   ├── sukkub/
│   └── azazel/
├── modules/               # Shared modules
│   ├── system/           # System-level
│   └── laptop/           # Laptop-specific
├── users/                 # User configurations
│   └── marcin/
└── secrets/               # Encrypted secrets
```

## ⚠️ Important Notes

1. **Hardware configs are placeholders** - replace with generated files during installation
2. **Generate age keys per host** - never copy private keys between machines
3. **Backup your age keys** - store securely offsite
4. **Test on sukkub first** - it's the POC machine

## 📝 License

Personal configuration - use at your own risk.
