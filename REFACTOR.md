# Server Infrastructure Refactoring

## Summary

This branch refactors server configuration to improve organization, security, and scalability.

## Changes Made

### 1. Directory Structure

**Before:**
```
hosts/
  containers/
    nixos-test/
modules/
  home/
    server-profile.nix
```

**After:**
```
hosts/
  servers/              # Unified location for all servers (LXC, VM, physical, ARM)
    nixos-test/
modules/
  servers/              # Server-specific modules
    users.nix           # nixadm user definition
users/
  nixadm/               # Dedicated admin user (instead of root)
    home.nix
```

### 2. Security Improvements

- **New admin user**: `nixadm` replaces direct root login
- **Disabled root SSH**: `PermitRootLogin = "no"` enforced
- **Passwordless sudo**: `nixadm` has sudo without password (wheel group)
- **SSH key only**: No password authentication

### 3. DNS Integration

- FreeIPA DNS configuration in `networking`:
  - `domain = "home.lan"`
  - `nameservers = [ "192.168.50.1" ]`
  - `search = [ "home.lan" ]`
- No full LDAP/Kerberos integration (preserves declarative user management)

### 4. Unified Configuration

- `users/nixadm/home.nix` provides identical shell environment on all servers:
  - Same aliases
  - Same tools (atuin, starship, zoxide, eza)
  - Same prompt
  - No atuin daemon (server-appropriate)

## Files Modified

### New Files
- `modules/servers/users.nix` - nixadm user definition
- `users/nixadm/home.nix` - home-manager config for nixadm
- `hosts/servers/nixos-test/configuration.nix` - moved from hosts/containers
- `hosts/servers/nixos-test/hardware-configuration.nix` - LXC hardware config

### Modified Files
- `flake.nix`:
  - Updated `colmena.nixos-test.deployment.targetUser` to `"nixadm"`
  - Updated paths: `hosts/containers` → `hosts/servers`
  - Changed home-manager user from `root` to `nixadm`
  - Added `trusted-users` and `sandbox = false` for LXC deployment

### Removed Files
- `modules/home/server-profile.nix` - replaced by `users/nixadm/home.nix`
- `hosts/containers/nixos-test/configuration.nix` - moved to `hosts/servers`

## Known Issues & Solutions

### Issue 1: Bootstrap Chicken-Egg Problem

**Problem:** Initial deployment fails because Colmena tries to SSH as `nixadm`, but user doesn't exist yet.

**Error:**
```
nixadm@192.168.50.6: Permission denied (publickey)
```

**Solution:** First deployment must be done manually as root:

```bash
# Step 1: Clone repo on server as root
ssh root@192.168.50.6
git clone https://github.com/waltharius/nixos.git /tmp/nixos
cd /tmp/nixos
git checkout refactor-servers

# Step 2: Manual rebuild to create nixadm user
nixos-rebuild switch --flake .#nixos-test --option sandbox false

# Step 3: Verify nixadm exists
id nixadm
su - nixadm  # Test login

# Step 4: Now Colmena works from laptop
exit  # Back to laptop
colmena apply --on nixos-test
```

**Why this happens:** 
- Colmena needs SSH access to deploy
- But SSH user (`nixadm`) is created by the deployment itself
- First deployment must be done locally on server as root

**Prevention for future servers:**
- Keep bootstrap script for initial setup
- Or temporarily enable root SSH for first deploy, then disable

### Issue 2: Trusted Keys Error

**Problem:** Colmena fails to copy store paths to server.

**Error:**
```
error: cannot add path '/nix/store/...' because it lacks a signature by a trusted key
```

**Root cause:** 
- Nix requires signed packages when copying between machines (security feature)
- `nixadm` is not in `trusted-users` list on server
- Server rejects unsigned packages from laptop

**Solution:** Add to `configuration.nix`:

```nix
nix.settings = {
  # Trust nixadm and wheel group for Colmena deployments
  trusted-users = [ "nixadm" "root" "@wheel" ];
  
  # Disable sandbox in LXC containers (kernel namespace limitations)
  sandbox = false;
};
```

**Why this is safe:**
- Homelab environment (you control all users)
- `nixadm` is admin user anyway (has sudo)
- `trusted-users` only affects Nix operations, not system security
- Alternative would be setting up binary cache with signing keys (overkill for homelab)

### Issue 3: Bash Profile Loop During Activation

**Problem:** After `nixos-rebuild`, terminal hangs with repeated errors:

```
-bash: /etc/profiles/per-user/root/bin/starship: No such file or directory
-bash: /etc/profiles/per-user/root/bin/starship: No such file or directory
...
```

**Root cause:**
- Old root `.bashrc` tries to load starship from old profile
- New config doesn't have home-manager for root anymore
- Only `nixadm` has home-manager now
- Old profile files still referenced

**Solution:** 

```bash
# Ctrl+C to break loop
# Option 1: Logout and login again
logout

# Option 2: Clear old profiles
rm -f ~/.bashrc ~/.bash_profile
exec bash

# Option 3: Use Proxmox console if SSH hangs
```

**Prevention:**
- When migrating users, clean old profiles first
- Or add explicit shell config for root:
  ```nix
  users.users.root.shell = pkgs.bashInteractive;
  ```

### Issue 4: home-manager Command Not Found (Not an Issue!)

**Observation:** On server, `home-manager` CLI is not available:

```bash
nixadm@nixos-test:~$ home-manager generations
-bash: home-manager: command not found
```

**This is NORMAL and CORRECT:**
- Home-manager is managed by Colmena, not by user
- Server gets home-manager config through NixOS module integration
- CLI tool is not needed (and not installed)
- Configuration still works perfectly (atuin, starship, aliases all work)

**If you need the CLI for debugging:**
```nix
# In users/nixadm/home.nix
home.packages = with pkgs; [
  home-manager  # Adds CLI tool
];
```

But this is usually unnecessary on servers.

## Testing Instructions

### Prerequisites

1. Ensure you have SSH access to nixos-test with current root credentials
2. Your SSH key must be in the server's authorized_keys

### Step 1: Pull the branch

```bash
cd ~/nixos/
git fetch origin
git checkout refactor-servers
```

### Step 2: Check flake syntax

```bash
nix flake check
```

Expected: No errors (warning about 'colmena' is normal)

### Step 3: Bootstrap server (FIRST TIME ONLY)

```bash
# SSH to server as root
ssh root@192.168.50.6

# Clone and checkout branch
git clone https://github.com/waltharius/nixos.git /tmp/nixos
cd /tmp/nixos
git checkout refactor-servers

# Manual rebuild to create nixadm
nixos-rebuild switch --flake .#nixos-test --option sandbox false

# Verify nixadm exists
id nixadm
logout
```

### Step 4: Deploy with Colmena

```bash
# Back on laptop
colmena apply --on nixos-test

# This will:
# - Connect as nixadm
# - Apply home-manager configuration
# - Activate all services
```

### Step 5: Test SSH with new user

```bash
# OLD (will FAIL after deployment):
ssh root@192.168.50.6
# Expected: Permission denied

# NEW (should work):
ssh nixadm@192.168.50.6
# Expected: Login successful with starship prompt
```

### Step 6: Verify nixadm environment

```bash
ssh nixadm@192.168.50.6

# Test sudo
sudo whoami
# Expected: root (no password prompt)

# Test atuin
echo "test command"
atuin search test
# Expected: Shows "test command" in history

# Test starship prompt
# Expected: Colored prompt showing: nixadm@nixos-test:/path

# Test aliases
ll      # eza listing
gs      # git status
z /tmp  # zoxide jump
# Expected: All work correctly
```

### Step 7: Test Colmena with new user

```bash
# On laptop
colmena apply --on nixos-test

# Should connect as nixadm (not root) and apply successfully
```

## Rollback Plan

If something goes wrong:

```bash
# Option 1: SSH as root still works (before reboot)
ssh root@192.168.50.6
sudo nixos-rebuild switch --flake github:waltharius/nixos#nixos-test --option ref main

# Option 2: From Proxmox console
# Login to container console in Proxmox UI
nixos-rebuild switch --flake github:waltharius/nixos#nixos-test --option ref main

# Option 3: Revert git branch
cd ~/nixos/
git checkout main
colmena apply --on nixos-test
```

## Future Additions

This structure supports easy addition of:

### More servers
```bash
mkdir -p hosts/servers/bookstack
mkdir -p hosts/servers/immich
mkdir -p hosts/servers/walthipi    # ARM Raspberry Pi
```

### Multi-architecture
```nix
# In flake.nix
walthipi = mkHost "servers/walthipi" "aarch64-linux";
```

### Service modules
```bash
mkdir -p modules/services
touch modules/services/immich.nix
touch modules/services/bookstack.nix
```

## Security Notes

### Why nixadm instead of root?

1. **Audit trail**: Know who logged in (not just "root")
2. **Best practice**: Industry standard to disable root SSH
3. **Flexibility**: Can add more admin users if needed
4. **Emergency access**: Can still login via Proxmox console if needed

### Why passwordless sudo?

- Servers are accessed via SSH key only (very secure)
- No interactive sessions where password could be sniffed
- Colmena needs passwordless access for automated deployments
- If SSH key is compromised, sudo password wouldn't help (attacker already has shell)

### Why trusted-users?

- Required for Colmena to copy store paths from laptop to server
- Safe in homelab (you control all users)
- Alternative (binary cache with signing) is overkill for homelab
- Only affects Nix operations, not system security

## Questions?

If you encounter issues:

1. Check `/var/log/nixos/` on server
2. Verify SSH key is correct in `modules/servers/users.nix`
3. Test from Proxmox console if SSH fails
4. Review commit history: `git log --oneline refactor-servers`
5. Check Known Issues section above

## Merge Checklist

- [x] `nix flake check` passes
- [x] Deployed successfully to nixos-test
- [x] Can SSH as nixadm
- [x] Atuin works
- [x] Starship prompt displays correctly
- [x] Sudo works without password
- [x] Colmena deploy works with nixadm user
- [x] hardware-configuration.nix added
- [x] Documentation reviewed and updated
- [x] Known Issues documented
- [x] No issues found during testing

Once all checked, merge to main:
```bash
cd ~/nixos/
git checkout main
git merge refactor-servers
git push origin main

# Optionally delete the branch
git branch -d refactor-servers
git push origin --delete refactor-servers
```
