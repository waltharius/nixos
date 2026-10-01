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
- **Server Deployment**: Automated deployment with Colmena for remote servers

## 📁 Repository Structure

```
nixos/
├── flake.nix                  # Main flake configuration
├── flake.lock                 # Locked dependencies
├── colmena.nix                # Colmena deployment configuration
├── .sops.yaml                 # SOPS encryption rules
│
├── hosts/                     # Host-specific configurations
│   ├── sukkub/               # ThinkPad P50 (test host)
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   ├── azazel/               # ThinkPad T16 (production)
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── servers/              # Remote servers (LXC containers)
│       ├── cloud-apps/       # Nextcloud + Syncthing
│       ├── nixos-test/       # Test server
│       └── actual-budget/    # Budget app
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
│   ├── services/             # User services
│   │   ├── ssh.nix          # SSH client + encrypted keys
│   │   └── syncthing.nix    # File synchronization
│   │
│   └── servers/              # Server-specific modules
│       ├── base-lxc.nix     # Base LXC container config
│       └── roles/           # Server roles
│           ├── nextcloud.nix
│           └── syncthing.nix
│
├── scripts/                   # Deployment and utility scripts
│   ├── deploy-cloud-apps.sh  # Safe deployment for cloud-apps
│   └── create-proxmox-lxc-from-template.sh
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

1. **Register the host**: `nix run .#new-host` (see [docs/NEW-HOST.md](docs/NEW-HOST.md))
2. **Boot the NixOS installer USB** on the machine
3. **Install from azazel**: `nix run .#install-host -- <host> root@<address>`
4. **Secrets and SSH**: [secrets/README.md](secrets/README.md), [docs/SSH.md](docs/SSH.md)

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

### Server Deployment

For remote servers (LXC containers), use the deployment scripts:

```bash
# Deploy to cloud-apps server with automatic reboot (RECOMMENDED)
./scripts/deploy-cloud-apps.sh

# Deploy without reboot (NOT recommended for major upgrades)
./scripts/deploy-cloud-apps.sh --no-reboot

# Deploy to other servers using colmena directly
colmena apply --on nixos-test
colmena apply --on actual-budget

# Deploy to all servers with specific tags
colmena apply --on @prod  # All production servers
colmena apply --on @test  # All test servers
```

#### Why Automatic Reboot?

The `deploy-cloud-apps.sh` script includes automatic reboot because:

- **Prevents activation conflicts**: During NixOS configuration switches, services may reference old paths from `/nix/store/`
- **Ensures clean state**: Especially important for Nextcloud and database services during major version upgrades
- **Avoids boot failures**: Services started during activation can fail if they try to use files that are being updated

The script will:
1. ✅ Deploy configuration via Colmena
2. 🔄 Reboot the server automatically
3. ⏳ Wait for server to come back online
4. 🔍 Verify all critical services are running
5. 📊 Show deployment summary

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

- **[NEW-HOST.md](docs/NEW-HOST.md)**: adding and installing a host (`new-host`, `install-host`)
- **[secrets/README.md](secrets/README.md)**: secrets, generated `.sops.yaml`, host keys
- **[SSH.md](docs/SSH.md)**: keys, layered host lists, pinned host keys
- **[hosts/README.md](hosts/README.md)**: inventory fields (machines, devices)
- **[WIFI_SETUP.md](docs/WIFI_SETUP.md)**: WiFi configuration with encrypted passwords (to be reviewed)
- **docs/history/**: logs of past work (upgrade to 26.05, local LLM on altair)

## 🖥️ Hosts

### Workstations

#### Sukkub (Test/POC)

- **Hardware**: Lenovo ThinkPad P50
- **CPU**: Intel (no specific optimizations)
- **Storage**: NVMe with LUKS encryption
- **Special**: No battery, no TLP
- **Purpose**: Testing new configurations

#### Azazel (Production)

- **Hardware**: Lenovo ThinkPad T16 Gen 3
- **CPU**: AMD (optimized for Zen)
- **RAM**: 128GB
- **Storage**: NVMe with LUKS encryption
- **Special**: TLP for battery, hibernate support
- **Purpose**: Daily driver

### Servers (LXC Containers on Proxmox)

#### cloud-apps (Production)

- **IP**: 192.168.50.8
- **Services**: Nextcloud 32, Syncthing
- **Database**: MariaDB with Redis cache
- **Storage**: Bind-mounted directories from Proxmox
- **Deployment**: Use `./scripts/deploy-cloud-apps.sh`

#### nixos-test (Testing)

- **IP**: 192.168.50.6
- **Purpose**: Test new server configurations before production
- **Deployment**: `colmena apply --on nixos-test`

#### actual-budget (Production)

- **IP**: 192.168.50.7
- **Services**: Actual Budget (budgeting app)
- **Deployment**: `colmena apply --on actual-budget`

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

### Server Deployment Issues

```bash
# If deployment fails, check connectivity
ping 192.168.50.8
ssh nixadm@192.168.50.8

# Check server logs
ssh nixadm@192.168.50.8 'sudo journalctl -u nextcloud-setup.service -n 100'

# Manually reboot if needed
ssh nixadm@192.168.50.8 'sudo reboot'

# Check service status after reboot
ssh nixadm@192.168.50.8 'sudo systemctl status nextcloud-setup.service'
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
- [Colmena](https://github.com/zhaofengli/colmena) - Simple, stateless NixOS deployment tool
- [nixd](https://github.com/nix-community/nixd) - Nix language server
- [NetworkManager](https://networkmanager.dev/) - Network connection manager

## 🔗 Useful Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/) - Deep dive into Nix
- [NixOS Wiki](https://nixos.wiki/)
- [SOPS Documentation](https://github.com/getsops/sops)
- [Colmena Documentation](https://colmena.cli.rs/)
- [NetworkManager Documentation](https://networkmanager.dev/docs/)

---

**Last Updated**: February 2026  
**NixOS Version**: 25.11  
**Status**: ✅ Production Ready
