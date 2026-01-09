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

### Modified Files
- `flake.nix`:
  - Updated `colmena.nixos-test.deployment.targetUser` to `"nixadm"`
  - Updated paths: `hosts/containers` → `hosts/servers`
  - Changed home-manager user from `root` to `nixadm`

### Removed Files
- `modules/home/server-profile.nix` - replaced by `users/nixadm/home.nix`
- `hosts/containers/nixos-test/configuration.nix` - moved to `hosts/servers`

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

Expected: No errors

### Step 3: Deploy to test server

```bash
# Deploy with Colmena
colmena apply --on nixos-test

# This will:
# - Create nixadm user
# - Configure home-manager for nixadm
# - Disable root SSH login
# - Apply new configuration
```

### Step 4: Test SSH with new user

```bash
# OLD (will FAIL after deployment):
ssh root@192.168.50.6
# Expected: Permission denied

# NEW (should work):
ssh nixadm@192.168.50.6
# Expected: Login successful
```

### Step 5: Verify nixadm environment

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
ll
gs
# Expected: eza and git shortcuts work

# Check home-manager
home-manager generations
# Expected: Shows generation list
```

### Step 6: Test Colmena with new user

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

## Questions?

If you encounter issues:

1. Check `/var/log/nixos/` on server
2. Verify SSH key is correct in `modules/servers/users.nix`
3. Test from Proxmox console if SSH fails
4. Review commit history: `git log --oneline refactor-servers`

## Merge Checklist

- [ ] `nix flake check` passes
- [ ] Deployed successfully to nixos-test
- [ ] Can SSH as nixadm
- [ ] Atuin works
- [ ] Starship prompt displays correctly
- [ ] Sudo works without password
- [ ] Colmena deploy works with nixadm user
- [ ] Documentation reviewed
- [ ] No issues found during testing

Once all checked, merge to main:
```bash
git checkout main
git merge refactor-servers
git push
```
