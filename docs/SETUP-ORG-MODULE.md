# Setup Guide: Org-Mode Module for Neovim

## Quick Start

### Step 1: Enable the Org-Mode Module

Edit `modules/utils/neovim.nix` and add the import:

```nix
{ pkgs, ... }:

{
  imports = [
    ./neovim-org.nix  # ← Add this line
  ];

  programs.neovim = {
    enable = true;
    # ... rest of your config
  };
}
```

### Step 2: Rebuild System

```bash
cd ~/nixos
sudo nixos-rebuild switch --flake .
```

### Step 3: Test It!

```bash
# Open Neovim
nvim

# Create today's journal
# Press: Space n j

# You should see a message:
# 📓 Org-mode module loaded! Use <leader>nj for journal, <leader>nn for notes
```

---

## Fix LaTeX PDF Export (Emacs)

### Problem

When exporting org files to PDF in Emacs, you get:
```
/run/current-system/sw/bin/bash: line 1: pdflatex: command not found
```

### Solution: Add LaTeX to System Packages

#### Option 1: Add to your main configuration.nix

```nix
# In your main system configuration
environment.systemPackages = with pkgs; [
  # ... your existing packages
  
  # LaTeX for org-mode PDF export
  texlive.combined.scheme-medium  # Medium installation (recommended)
  # OR
  # texlive.combined.scheme-full   # Full installation (larger, ~4GB)
  # OR  
  # texlive.combined.scheme-basic  # Minimal (may miss some packages)
];
```

#### Option 2: Add to Emacs packages specifically

If you manage Emacs separately (e.g., in home-manager):

```nix
home.packages = with pkgs; [
  # ... your packages
  texlive.combined.scheme-medium
];
```

#### Option 3: Quick Test (Temporary)

Test before committing to your config:

```bash
# Install temporarily
nix-shell -p texlive.combined.scheme-medium

# Now try PDF export in Emacs
emacs your-note.org
# C-c C-e l p (export to PDF)
```

### Verify Installation

```bash
# After rebuild, check if pdflatex is available
which pdflatex
# Should show: /nix/store/.../bin/pdflatex

pdflatex --version
# Should show version info
```

---

## Configuration Examples

### Full Setup (Personal Laptop)

```nix
# ~/nixos/modules/utils/neovim.nix
{ pkgs, ... }:

{
  imports = [
    ./neovim-org.nix  # Org-mode enabled
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    # ... rest of config
  };
}
```

### Server Setup (No Org-Mode)

```nix
# ~/nixos/modules/utils/neovim.nix
{ pkgs, ... }:

{
  imports = [
    # ./neovim-org.nix  # Disabled for server
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    # ... rest of config
  };
}
```

### Child's Laptop (No Org-Mode)

```nix
# In child's home-manager configuration
{ pkgs, ... }:

{
  imports = [
    ../../modules/utils/neovim.nix  # Only core Neovim
    # NOT importing neovim-org.nix
  ];
}
```

---

## Testing Checklist

### ☑️ Neovim Org-Mode Module

- [ ] Module loads without errors
  ```bash
  nvim
  # Should see: 📓 Org-mode module loaded!
  ```

- [ ] Today's journal works
  ```vim
  " In Neovim
  <leader>nj
  # Creates: ~/notes/YYYYMMDDTHHMMSS--YYYY-MM-DD-journal__journal.org
  ```

- [ ] Past date journal works
  ```vim
  <leader>nJ
  # Prompts for date, creates with T000000
  ```

- [ ] Note creation works
  ```vim
  <leader>nn
  # Prompts for title and tags
  ```

- [ ] Spell checking active
  ```vim
  :set spell?
  # Should show: spell
  
  :set spelllang?
  # Should show: spelllang=en_us,pl
  ```

- [ ] File format matches Emacs
  ```bash
  # Create note in Neovim
  nvim
  <leader>nn
  
  # Open same note in Emacs
  emacs ~/notes/[filename].org
  # Should look identical
  ```

### ☑️ Emacs PDF Export

- [ ] pdflatex available
  ```bash
  which pdflatex
  ```

- [ ] PDF export works
  ```bash
  emacs ~/notes/test.org
  # C-c C-e l p (org-export to PDF and open)
  # Should create PDF in ~/notes/pdf/test.pdf
  ```

- [ ] Polish characters render correctly
  ```org
  Test: ą ć ę ł ń ó ś ź ż
  # Export to PDF, check if characters appear
  ```

---

## Troubleshooting

### Issue: Module not loading

**Symptom:** No message when opening Neovim

**Solution:**
```bash
# Check if import is correct
cat modules/utils/neovim.nix | grep neovim-org

# Rebuild with verbose output
sudo nixos-rebuild switch --flake . --show-trace
```

### Issue: orgmode plugin missing

**Symptom:** Error about orgmode not found

**Solution:**
```bash
# Check if vimPlugins.orgmode is in nixpkgs
nix-env -qa 'vimPlugins.orgmode'

# If missing, try updating flake
cd ~/nixos
nix flake update
sudo nixos-rebuild switch --flake .
```

### Issue: LaTeX not found after install

**Symptom:** pdflatex still not found

**Solution:**
```bash
# Check if texlive is in system packages
nix-store -q --references /run/current-system | grep texlive

# If missing, verify configuration.nix change
cat /etc/nixos/configuration.nix | grep texlive

# Rebuild ensuring texlive is included
sudo nixos-rebuild switch --flake . --show-trace
```

### Issue: Polish spell checking not working

**Symptom:** Polish words marked as errors

**Solution:**
```bash
# Install Polish dictionaries
nix-shell -p aspell aspellDicts.pl hunspell hunspellDicts.pl_PL

# In Neovim, verify
:set spelllang?
# Should include 'pl'

# If not, add manually
:set spelllang=en_us,pl
```

---

## Rollback Procedure

If something goes wrong:

### Remove Org-Mode Module

```nix
# Edit modules/utils/neovim.nix
imports = [
  # ./neovim-org.nix  # Commented out
];
```

```bash
cd ~/nixos
sudo nixos-rebuild switch --flake .
```

### Rollback Entire System

```bash
# List previous generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or to specific generation
sudo /nix/var/nix/profiles/system-42-link/bin/switch-to-configuration switch
```

---

## Advanced: Per-Machine Configuration

Use NixOS modules to enable org-mode only on specific machines:

### Create conditional module

```nix
# modules/utils/neovim-conditional.nix
{ config, lib, pkgs, ... }:

let
  hostname = config.networking.hostName;
  enableOrgMode = builtins.elem hostname [ "laptop" "desktop" "p50" ];
in
{
  imports = lib.optionals enableOrgMode [
    ./neovim-org.nix
  ];
  
  programs.neovim = {
    enable = true;
    # ... rest of config
  };
}
```

### Use in configuration

```nix
# Instead of importing neovim.nix directly
imports = [
  ./modules/utils/neovim-conditional.nix
];
```

Now org-mode only loads on machines named "laptop", "desktop", or "p50"!

---

## Next Steps

1. ✅ Enable the module
2. ✅ Fix LaTeX for Emacs
3. ✅ Test journal workflow
4. 📚 Read [neovim-org.md](./neovim-org.md) for complete documentation
5. ✨ Start using Neovim and Emacs interchangeably!

---

## Support

If you encounter issues:

1. Check this guide's troubleshooting section
2. Review [neovim-org.md](./neovim-org.md) documentation  
3. Check Neovim logs: `:messages`
4. Test with minimal config: `nvim --clean`

---

*Last updated: 2026-01-02*
