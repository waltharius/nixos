# NixOS Configuration Documentation

## Neovim Configuration

### Core Configuration

- **[neovim-keybindings.md](./neovim-keybindings.md)** - Complete Neovim keybindings reference
  - LSP, Git (Neogit), Telescope, Folding
  - All shortcuts and workflows
  - Tips and troubleshooting

### Optional Modules

#### Org-Mode Support (NEW! 🎉)

- **[SETUP-ORG-MODULE.md](./SETUP-ORG-MODULE.md)** - ⭐ **START HERE**
  - Quick setup guide
  - Enable/disable instructions
  - LaTeX PDF export fix for Emacs
  - Testing checklist

- **[neovim-org.md](./neovim-org.md)** - Complete org-mode documentation
  - Journal workflow (exactly like Emacs)
  - Denote-style note-taking
  - Spell checking (EN + PL)
  - Emacs compatibility guide

---

## Quick Start: Enable Org-Mode

### 1. Add Import

Edit `modules/utils/neovim.nix`:

```nix
{ pkgs, ... }:

{
  imports = [
    ./neovim-org.nix  # ← Add this line
  ];
  
  programs.neovim = {
    # ... existing config
  };
}
```

### 2. Rebuild

```bash
cd ~/nixos
sudo nixos-rebuild switch --flake .
```

### 3. Test

```bash
nvim
# Press: Space n j (create today's journal)
```

---

## Feature Comparison

### Core Neovim (Always Active)

✅ LSP (Nixd, Lua Language Server)
✅ Auto-formatting (alejandra, stylua, black, prettier)
✅ Git integration (Neogit, gitsigns)
✅ Fuzzy finding (Telescope)
✅ Code folding (nvim-ufo)
✅ Completion (nvim-cmp)
✅ Visual aids (indent guides, scope highlighting)

### Org-Mode Module (Optional)

✅ Org-mode support (orgmode.nvim)
✅ Denote-style journaling
✅ Spell checking (English + Polish)
✅ Note creation with tags
✅ Emacs-compatible format
❌ Calendar view (use Emacs)
❌ PDF export (use Emacs + LaTeX)

---

## Modular Design

### Philosophy

- **Core config**: Always enabled (code editing)
- **Optional modules**: Import only what you need
- **Safe to disable**: No side effects on core functionality

### Use Cases

**Personal laptop:** Core + Org-mode
```nix
imports = [ ./neovim-org.nix ];
```

**Server:** Core only (no org-mode)
```nix
imports = [ # ./neovim-org.nix  # disabled
];
```

**Child's laptop:** Core only
```nix
imports = [ # ./neovim-org.nix  # not needed
];
```

---

## File Structure

```
~/nixos/
├── modules/utils/
│   ├── neovim.nix          # Main Neovim configuration
│   └── neovim-org.nix      # Org-mode module (optional)
│
└── docs/
    ├── README.md                # This file
    ├── neovim-keybindings.md    # Core Neovim reference
    ├── SETUP-ORG-MODULE.md      # Org-mode setup guide
    └── neovim-org.md            # Org-mode documentation
```

---

## Workflow Examples

### Daily Journal (with org-mode)

```bash
# Morning journal
nvim
<Space>nj
# Write your entry, save with :w

# Later: add another entry
nvim
<Space>nj  # Adds new time section

# Next day in Emacs (same file!)
emacs ~/notes/20260102T094530--2026-01-02-journal__journal.org
# File opens perfectly - same format
```

### Code Development

```bash
# Edit NixOS config
nvim ~/nixos/flake.nix

# Format on save (automatic)
# LSP diagnostics (automatic)
# Git integration
<Space>gs  # Open Neogit status
s          # Stage changes
cc         # Commit
pp         # Push
```

### Note Taking

```bash
# Create note in Neovim
nvim
<Space>nn
Title: NixOS Flakes
Tags: nixos learning

# Later: edit in Emacs
emacs ~/notes/20260102T153045--nixos-flakes__nixos_learning.org
# Everything works!
```

---

## Quick Reference

### Core Keybindings

| Function | Keybinding | Description |
|----------|------------|-------------|
| **Files** |
| Find files | `<Space>ff` | Fuzzy file finder |
| Live grep | `<Space>fg` | Search in files |
| Buffers | `<Space>fb` | Switch buffers |
| **Git** |
| Git status | `<Space>gs` | Open Neogit |
| Git commit | `<Space>gc` | Commit menu |
| Git push | `<Space>gp` | Push menu |
| Git blame | `<Space>gb` | Toggle blame |
| **Code** |
| Go to def | `gd` | Jump to definition |
| Hover docs | `K` | Show documentation |
| Format | `<Space>f` | Format buffer |

### Org-Mode Keybindings (when enabled)

| Function | Keybinding | Description |
|----------|------------|-------------|
| Today journal | `<Space>nj` | Create/append journal |
| Past journal | `<Space>nJ` | Journal for specific date |
| New note | `<Space>nn` | Create note with tags |
| Toggle spell | `<Space>ns` | Spell check on/off |
| Spell suggest | `z=` | Spelling suggestions |

---

## Troubleshooting

### Common Issues

1. **Org-mode not loading**
   - Check: `imports = [ ./neovim-org.nix ];` in neovim.nix
   - Rebuild: `sudo nixos-rebuild switch --flake .`

2. **PDF export fails in Emacs**
   - Add to configuration.nix: `texlive.combined.scheme-medium`
   - See [SETUP-ORG-MODULE.md](./SETUP-ORG-MODULE.md#fix-latex-pdf-export-emacs)

3. **Spell checking not working**
   - Packages included: aspell, hunspell + dictionaries
   - Toggle in Neovim: `<Space>ns`

---

## Support

- 📚 Read the docs (linked above)
- 🔍 Search issues: `:messages` in Neovim
- 🔧 Check config: `~/nixos/modules/utils/`
- 🔄 Rollback: `sudo nixos-rebuild switch --rollback`

---

## Contributing

Improvements welcome! When modifying:

1. Test on personal laptop first
2. Ensure backward compatibility
3. Update relevant documentation
4. Keep modules independent (can be disabled)

---

*Last updated: 2026-01-02*
