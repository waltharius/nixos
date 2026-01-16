# Users Directory

This directory contains home-manager configurations for all users across all hosts.

## Structure

```
users/
├── marcin/              # Marcin's laptop user configs
│   ├── core.nix         # Identity: git, SSH, SOPS (always included)
│   ├── maintainer.nix   # CLI tools for remote admin (imports core.nix)
│   └── desktop.nix      # Full GUI desktop (imports maintainer.nix)
│
├── nixadm/              # Server admin user (SERVERS ONLY!)
│   └── home.nix
│
├── TEMPLATE-USER/       # Template for creating new users
│   └── default.nix
│
└── README.md            # This file
```

## User Types

### Laptop Users (marcin, future family members)
- Located directly in `users/USERNAME/`
- Used on physical laptops and workstations
- Can have GUI apps and desktop environments
- Multiple users can exist on one laptop

### Server Users (nixadm)
- Used ONLY on servers (LXC containers, VMs)
- CLI-only, no GUI
- Separate from laptop users

## Marcin's Three Configs

### 1. `core.nix` - Identity
**Contains:** Git, SSH keys, SOPS, fonts  
**Used by:** Both `maintainer.nix` and `desktop.nix`  
**Use case:** Never used alone, always imported

### 2. `maintainer.nix` - CLI Admin
**Imports:** `core.nix`  
**Adds:** Shell tools, nixvim, tmux, nix tools, colmena  
**Use case:** SSH admin access to family laptops  
**Example:**
```nix
# On mum's laptop - Marcin has admin access but no GUI
users.marcin = import ./users/marcin/maintainer.nix;
```

### 3. `desktop.nix` - Full Desktop
**Imports:** `maintainer.nix` (gets all CLI tools)  
**Adds:** GNOME apps, office apps, media apps, Logitech configs  
**Use case:** Your personal laptops (sukkub, azazel)  
**Example:**
```nix
# On your laptop - Full GUI + CLI tools
users.marcin = import ./users/marcin/desktop.nix;
```

## Adding a New User

See [docs/MULTI-USER-GUIDE.md](../docs/MULTI-USER-GUIDE.md) for detailed instructions.

**Quick steps:**
1. Copy template: `cp -r users/TEMPLATE-USER users/newuser`
2. Edit `users/newuser/default.nix`
3. Add to host config in `hosts/HOSTNAME/configuration.nix`
4. Update `flake.nix` to include the new user
5. Deploy!

## Rules

✅ **DO:**
- Create one directory per user
- Keep configs simple and focused
- Use `maintainer.nix` for admin-only access
- Use templates for new users

❌ **DON'T:**
- Mix laptop and server users
- Use `desktop.nix` on family laptops (they don't need your tools)
- Create deep subdirectory structures
- Duplicate configs across users

## Examples

### Scenario 1: Your Laptop
```nix
# flake.nix
users.marcin = import ./users/marcin/desktop.nix;
```
Result: Full GUI + CLI tools

### Scenario 2: Mum's Laptop (Two Users)
```nix
# flake.nix
users = {
  mum = import ./users/mum;
  marcin = import ./users/marcin/maintainer.nix;  # Admin only!
};
```
Result: Mum gets GUI, you get SSH admin access

### Scenario 3: Server
```nix
# flake.nix (in mkServer)
users.nixadm = import ./users/nixadm/home.nix;
```
Result: Server admin, NO laptop users

## Migration Status

- ✅ Marcin's config split into modules
- ✅ Template created for new users
- ✅ Documentation written
- ⏳ Ready to test on sukkub
- ⏳ Ready to add family members

---

For more details, see:
- [docs/MULTI-USER-GUIDE.md](../docs/MULTI-USER-GUIDE.md) - Complete guide
- [docs/MIGRATION-NOTES.md](../docs/MIGRATION-NOTES.md) - What changed
