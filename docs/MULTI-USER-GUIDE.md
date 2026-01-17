# Multi-User Configuration Guide

This guide explains how to add new users to NixOS laptops while maintaining admin access.

## Current Structure

```
users/
├── marcin/              # Your user configs
│   ├── core.nix         # Identity (git, SSH, SOPS) - always included
│   ├── maintainer.nix   # CLI tools - for remote admin
│   └── desktop.nix      # Full GUI - for your personal laptops
│
├── nixadm/              # Server admin user (servers only!)
│   └── home.nix
│
└── TEMPLATE-USER/       # Template for new users
    └── default.nix      # Copy this to create new users
```

## Marcin's Three Configurations

### 1. `core.nix` - Identity Only

Contains:

- Git config
- SSH keys
- SOPS setup
- Basic settings

Used by: `maintainer.nix` and `desktop.nix`

### 2. `maintainer.nix` - CLI Admin Access

Imports: `core.nix` +  
Adds:

- CLI tools (ripgrep, fd, tree, etc.)
- Shell config (bash, starship, tmux)
- Nixvim, yazi, atuin, zoxide
- Nix tools (colmena, nh, sops)

Use this when: You need admin access to family laptops via SSH

### 3. `desktop.nix` - Full Desktop

Imports: `maintainer.nix` (gets all CLI tools) +  
Adds:

- GNOME apps (Brave, Signal, Spotify, etc.)
- Office apps (LibreOffice, Zotero, Obsidian)
- GNOME extensions and settings
- Logitech device configs

Use this when: Configuring personal laptop with full GUI

---

## How to Add a New User to a Laptop

### Scenario: Add "mum" as primary user to her laptop

#### Step 1: Create User Config

```bash
cd ~/nixos
cp -r users/TEMPLATE-USER users/mum
vim users/mum/default.nix
```

Edit `users/mum/default.nix`:

```nix
{ pkgs, ... }: {
  home.username = "mum";
  home.homeDirectory = "/home/mum";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Simple packages for mum
  home.packages = with pkgs; [
    brave
    libreoffice-fresh
    thunderbird
    nextcloud-client
  ];
}
```

#### Step 2: Update System Config

Edit `hosts/mums-laptop/configuration.nix`:

```nix
{ ... }: {
  # ... existing system config ...

  # Define TWO users: mum (primary) and yours user (admin)
  users.users = {
    # Mum - primary user, no sudo
    mum = {
      isNormalUser = true;
      description = "Mum";
      extraGroups = [ "networkmanager" "video" "audio" ];
      # NO "wheel" group = no sudo access
    };

    # You - admin access for maintenance
    marcin = {
      isNormalUser = true;
      description = "Marcin (Admin)";
      extraGroups = [ "wheel" "networkmanager" ];  # wheel = sudo!
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3Nza..." # Your SSH key
      ];
    };
  };
}
```

#### Step 3: Update Flake

Edit `flake.nix` in the `mkHost` function:

```nix
home-manager = {
  # ... existing config ...

  # CHANGE THIS from single user:
  # users.marcin = import ./users/marcin/desktop.nix;

  # TO multiple users:
  users = {
    mum = import ./users/mum;  # Her config
    marcin = import ./users/marcin/maintainer.nix;  # CLI only!
  };
};
```

#### Step 4: Deploy

```bash
# Test locally (if on the laptop)
sudo nixos-rebuild test --flake .#mums-laptop

# Or deploy remotely with colmena
colmena apply --on mums-laptop
```

---

## Common Patterns

### Your Personal laptop

```nix
users.marcin = import ./users/marcin/desktop.nix;
# Gets: CLI tools + Full GUI
```

### Family Member's Laptop (e.g. mums-laptop)

```nix
users = {
  mum = import ./users/mum;
  marcin = import ./users/marcin/maintainer.nix;  # CLI only!
};
# Mum gets GUI, you get SSH access for maintenance
```

### Server (e.g. nixos-test)

```nix
users.nixadm = import ./users/nixadm/home.nix;
# NO laptop users on servers!
```

---

## Important Rules

1. **Laptop users go in `users/`** (not in a subdirectory)
2. **Server users stay in `users/nixadm/`** (separate!)
3. **One config per user** - keep it simple
4. **Marcin (FAMILY ADMIN GUY) has two modes:**
   - `desktop.nix` = your personal laptops
   - `maintainer.nix` = family laptops (SSH admin only)
5. **rather don't use your `desktop.nix` on family laptops** - they don't need your personal tools!

---

## Troubleshooting

### "How do I SSH into mum's laptop?"

```bash
ssh marcin@mums-laptop  # Your SSH key is configured
sudo nixos-rebuild switch  # You have sudo (wheel group)
```

### "How do I deploy from my laptop?"

```bash
colmena apply --on mums-laptop  # Deploy to one laptop
colmena apply  # Deploy to all configured hosts
```

### "What if I need GUI on a family laptop?"

You probably don't! Use SSH + terminal. But if you must:

```nix
# In flake.nix, for that host only:
users.marcin = import ./users/marcin/desktop.nix;
```

---

## Next Steps

1. ✅ Test the new structure on sukkub
2. ✅ Verify SSH access works
3. ✅ Create first family member user when ready
4. ✅ Deploy and verify

Keep configs simple - add complexity only when needed!
