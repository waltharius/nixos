# NixOS Configuration

Multi-host NixOS configuration with flakes, home-manager, and sops-nix for secure secrets management.

## 🎯 Features

- **Declarative Configuration**: Everything in code, fully reproducible
- **Multi-Host Support**: Sukkub (test), Azazel (production)
- **Home Manager Integration**: User environment managed declaratively
- **Secrets Management**: SOPS with age encryption for SSH keys and WiFi passwords
- **WiFi**: NetworkManager with encrypted passwords + ad-hoc network support
- **Modern Development Setup**: Neovim with LSP, Git, Shell tools
- **GNOME Desktop**: Pre-configured with useful extensions

## 📁 Repository Structure

```
nixos/
├── flake.nix                  # Main flake configuration
├── flake.lock                 # Locked dependencies
├── .sops.yaml                 # SOPS encryption rules
│
├── hosts/                     # Host-specific configurations
│   ├── sukkub/               # ThinkPad P50 (test host)
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── azazel/               # ThinkPad T16 (production)
│       ├── configuration.nix
│       └── hardware-configuration.nix
│
├── users/                     # User configurations
│   └── marcin/
│       └── home.nix          # Home Manager config
│
├── modules/
│   ├── system/               # System-level modules
│   │   ├── boot.nix         # Bootloader configuration
│   │   ├── networking.nix   # Network settings
│   │   ├── locale.nix       # Localization
│   │   ├── gnome.nix        # GNOME desktop
│   │   ├── secrets.nix      # SOPS integration
│   │   ├── sshd.nix         # SSH server
│   │   └── wifi.nix         # WiFi with encrypted passwords
│   │
│   └── services/             # User services
│       ├── ssh.nix          # SSH client + encrypted keys
│       └── syncthing.nix    # File synchronization
│
├── secrets/                   # Encrypted secrets (SAFE to commit!)
│   ├── ssh.yaml              # Encrypted SSH keys
│   ├── wifi.yaml             # Encrypted WiFi passwords
│   └── *.yaml.example        # Templates for secrets
│
└── docs/                      # Documentation
    ├── INSTALLATION.md        # Step-by-step installation guide
    ├── SSH_KEYS_SETUP.md     # SSH keys and secrets setup
    └── WIFI_SETUP.md         # WiFi configuration guide
```

## 🚀 Quick Start

### For Fresh Installation

1. **Boot NixOS installer USB**
2. **Follow the guide**: [docs/INSTALLATION.md](docs/INSTALLATION.md)
3. **Configure secrets**: [docs/SSH_KEYS_SETUP.md](docs/SSH_KEYS_SETUP.md)
4. **Setup WiFi**: [docs/WIFI_SETUP.md](docs/WIFI_SETUP.md)

### Key Installation Steps:

```bash
# 1. Partition and encrypt disk
# 2. Clone repo to ~/nixos
git clone https://github.com/waltharius/nixos.git ~/nixos

# 3. Generate age key
mkdir -p /var/lib/sops-nix
age-keygen -o /var/lib/sops-nix/key.txt

# 4. Symlink to /etc/nixos
sudo ln -s ~/nixos /etc/nixos

# 5. Install
sudo nixos-install --flake ~/nixos#sukkub --no-root-password
```

## 📦 What's Included

### System Level

- **Boot**: systemd-boot with LUKS encryption
- **Desktop**: GNOME 47 with useful extensions
- **Networking**: NetworkManager with WiFi + encrypted passwords
- **Security**: Firewall, encrypted secrets, SSH keys
- **Services**: SSH server, Syncthing

### User Environment (Home Manager)

- **Shell**: Bash with ble.sh, starship prompt, zoxide
- **Editor**: Neovim with LSP (nixd, lua), completion, Telescope
- **Terminal**: Alacritty, tmux with plugins
- **Tools**: eza, ripgrep, fd, btop, yazi
- **Development**: Git with SSH keys, age/sops
- **History**: Atuin (self-hosted sync)

### GUI Applications

- Brave browser
- Signal Desktop
- Blanket (ambient sounds)
- Emacs (PGTK)

## 🔐 Security

### Secrets Management

- **SOPS + age**: All secrets encrypted with age
- **Per-host keys**: Each machine has unique age key
- **SSH keys**: Private keys never in plaintext
- **WiFi passwords**: Encrypted in git, decrypted to tmpfs
- **Git safe**: `secrets/` directory is safe to commit (encrypted)

### SSH Server

- **Key-only auth**: Password authentication disabled
- **No root login**: Root cannot SSH in
- **Firewall**: Only port 22 open

### WiFi Security

- **Passwords encrypted**: Never in Nix store or git plaintext
- **Hybrid approach**: Permanent networks in config + ad-hoc networks on-demand
- **NetworkManager**: Secure credential storage

## 🛠️ Daily Workflow

### Editing Configuration

```bash
# Edit as regular user (no sudo!)
vim ~/nixos/users/marcin/home.nix

# Commit changes
cd ~/nixos
git add .
git commit -m "Update: something"
git push
```

### Applying Changes

```bash
# System rebuild (requires sudo)
sudo nixos-rebuild switch --flake ~/nixos#sukkub

# Or use alias
nrs  # alias for the above command
```

### WiFi Management

```bash
# List available networks
wifi-list

# Connect to ad-hoc network (cafe, hotel)
wifi-connect "CafeName" password "guest123"

# Check connection status
wifi-status

# Forget network
wifi-forget "CafeName"

# Permanent networks (home, work) connect automatically
```

### On Another Host

```bash
# Pull changes
cd ~/nixos
sudo git pull

# Apply
sudo nixos-rebuild switch --flake ~/nixos#azazel
```

## 🔧 Useful Aliases

Defined in `users/marcin/home.nix`:

```bash
ll              # eza -alF with icons, git status, hyperlinks
gs              # git status
nrs             # sudo nixos-rebuild switch
wifi-list       # nmcli device wifi list
wifi-connect    # nmcli device wifi connect
wifi-status     # nmcli connection show --active
wifi-forget     # nmcli connection delete
atuin-local     # Search history for current host only
y               # yazi with cd on exit
```

## 📚 Documentation

- **[INSTALLATION.md](docs/INSTALLATION.md)**: Complete installation guide
- **[SSH_KEYS_SETUP.md](docs/SSH_KEYS_SETUP.md)**: SSH keys and secrets management
- **[WIFI_SETUP.md](docs/WIFI_SETUP.md)**: WiFi configuration with encrypted passwords

## 🖥️ Hosts

### Sukkub (Test/POC)

- **Hardware**: Lenovo ThinkPad P50
- **CPU**: Intel (no specific optimizations)
- **Storage**: NVMe with LUKS encryption
- **Special**: No battery, no TLP
- **Purpose**: Testing new configurations

### Azazel (Production)

- **Hardware**: Lenovo ThinkPad T16 Gen 3
- **CPU**: AMD (optimized for Zen)
- **RAM**: 128GB
- **Storage**: NVMe with LUKS encryption
- **Special**: TLP for battery, hibernate support
- **Purpose**: Daily driver

## 🔄 Update System

```bash
# Update flake inputs
cd ~/nixos
nix flake update

# Review changes
git diff flake.lock

# Rebuild with new versions
sudo nixos-rebuild switch --flake ~/nixos#sukkub

# If all good, commit
git add flake.lock
git commit -m "Update: flake inputs"
git push
```

## 🆘 Troubleshooting

### Secrets Not Decrypting

```bash
# Check age key exists
ls -la /var/lib/sops-nix/key.txt

# Show public key
sudo age-keygen -y /var/lib/sops-nix/key.txt

# Verify in .sops.yaml
cat ~/nixos/.sops.yaml

# Test manual decryption
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops -d ~/nixos/secrets/ssh.yaml
```

### WiFi Not Connecting

```bash
# Check NetworkManager status
systemctl status NetworkManager

# List connections
nmcli connection show

# Check if password was injected
sudo cat /etc/NetworkManager/system-connections/Home.nmconnection

# Manual reload
sudo systemctl reload NetworkManager
```

### Build Fails

```bash
# Check syntax
nix flake check ~/nixos

# Show full error
sudo nixos-rebuild switch --flake ~/nixos#sukkub --show-trace

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

### Git Issues

```bash
# If git complains about ownership
cd ~/nixos
git config --global --add safe.directory ~/nixos

# Check repository status
git status
git remote -v
```

## 📝 Contributing

This is a personal configuration, but feel free to:

- Use it as a reference for your own NixOS setup
- Open issues if you find bugs in documentation
- Submit PRs for typos or improvements

## 📜 License

MIT License - Use freely, no warranty provided.

## 🙏 Acknowledgments

- [NixOS](https://nixos.org/) - The purely functional Linux distribution
- [Home Manager](https://github.com/nix-community/home-manager) - Declarative user environment
- [SOPS-nix](https://github.com/Mic92/sops-nix) - Secrets management
- [nixd](https://github.com/nix-community/nixd) - Nix language server
- [NetworkManager](https://networkmanager.dev/) - Network connection manager

## 🔗 Useful Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/) - Deep dive into Nix
- [NixOS Wiki](https://nixos.wiki/)
- [SOPS Documentation](https://github.com/getsops/sops)
- [NetworkManager Documentation](https://networkmanager.dev/docs/)

---

**Last Updated**: December 2025  
**NixOS Version**: 25.11  
**Status**: ✅ Production Ready
