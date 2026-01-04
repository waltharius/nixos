# NixVim Configuration Guide

## Overview

This directory contains a complete NixVim configuration that replaces the previous `programs.neovim` setup.

### What Changed

- ✅ All plugin configurations ported to nixvim
- ✅ LSP servers (nixd, lua_ls) configured
- ✅ Same keybindings as before
- ✅ Org-mode support maintained
- ✅ Works for any user automatically (uses $HOME)

## Structure

```
modules/utils/nixvim/
├── default.nix      # Main entry point
├── core.nix         # Editor settings & colorscheme
├── plugins.nix      # All plugin configurations
├── lsp.nix          # LSP configuration
├── completion.nix   # nvim-cmp setup
├── formatting.nix   # Code formatters
├── keymaps.nix      # Keybindings
└── org-mode.nix     # Org-mode & spell checking
```

## Usage

### Switching to NixVim

In `users/marcin/home.nix`:

```nix
imports = [
  # ../../modules/utils/neovim.nix  # OLD
  ../../modules/utils/nixvim        # NEW
  # ... other imports
];
```

### Rebuilding

```bash
# Test first
sudo nixos-rebuild test --flake ~/nixos#$(hostname)

# If good, apply permanently
sudo nixos-rebuild switch --flake ~/nixos#$(hostname)
```

## Key Features

### Dynamic Configuration

- **Auto-detects home directory**: Works for any user
- **Hostname-aware LSP**: Adapts to your machine name
- **No hardcoded paths**: Everything computed at runtime

### LSP Configuration

The nixd LSP is configured to:
- Use your flake at `~/nixos`
- Auto-detect hostname for NixOS options
- Format with alejandra

### Keybindings

| Key | Action |
|-----|--------|
| `<Space>` | Leader key |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Find buffers |
| `<leader>gs` | Git status (Neogit) |
| `<leader>gb` | Toggle git blame |
| `<leader>f` | Format buffer |
| `<leader>u` | Undo tree |
| `<leader>w` | Save file |
| `<leader>q` | Quit |
| `<C-h/j/k/l>` | Window navigation |

## Troubleshooting

### Check Plugin Health

```bash
nvim -c "checkhealth" -c "quit"
```

### LSP Not Working

```vim
:LspInfo
```

Should show nixd and lua_ls attached.

### Reverting

To go back to old config:

1. Comment out nixvim import in `home.nix`
2. Uncomment `../../modules/utils/neovim.nix`
3. Rebuild

## Customization

### Add a Plugin

Edit `plugins.nix`:

```nix
plugins.your-plugin = {
  enable = true;
  settings = {
    # plugin options
  };
};
```

### Add a Keybinding

Edit `keymaps.nix`:

```nix
{
  mode = "n";
  key = "<leader>x";
  action = "<cmd>YourCommand<CR>";
  options = { desc = "Description"; };
}
```

### Change LSP Settings

Edit `lsp.nix` to add more language servers or modify existing ones.

## Benefits Over programs.neovim

- ✅ Type-safe configuration
- ✅ Better documentation
- ✅ Validated at build time
- ✅ More maintainable
- ✅ Clean module structure

## Additional Resources

- [NixVim Documentation](https://nix-community.github.io/nixvim/)
- [NixVim GitHub](https://github.com/nix-community/nixvim)
- [NixOS Discourse](https://discourse.nixos.org/)
