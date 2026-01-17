# Migration Notes: Old → New User Structure

## What Changed

### Before (main branch)

```
users/marcin/home.nix  # One giant file (290 lines)
```

### After (multi-user-config branch)

```
users/marcin/
├── core.nix         # Identity (git, SSH, SOPS)
├── maintainer.nix   # CLI tools (imports core.nix)
└── desktop.nix      # Full GUI (imports maintainer.nix)
```

## Benefits

1. **Reusable** - `maintainer.nix` can be used standalone on family laptops
2. **Clear separation** - Easy to see what belongs where
3. **Multi-user ready** - Easy to add new users
4. **No duplication** - Each config imports what it needs

## Behavioral Changes

**None!** The new `desktop.nix` is functionally identical to old `home.nix`.

All your packages, configs, and settings are preserved exactly as they were.

## Testing Checklist

On sukkub after switching to new branch:

- [ ] All GNOME extensions loaded
- [ ] All apps available (Brave, Signal, etc.)
- [ ] CLI tools work (nixvim, yazi, etc.)
- [ ] Git config correct
- [ ] SSH keys work
- [ ] SOPS secrets accessible
- [ ] Starship prompt shows
- [ ] Solaar works with Logitech devices

If anything is missing, check the imports in `desktop.nix`.

## Rollback Plan

```bash
# If something breaks, switch back to main:
sudo nixos-rebuild switch --flake .#sukkub
# Or select previous generation in GRUB menu
```

The old `users/marcin/home.nix` still exists on main branch.
