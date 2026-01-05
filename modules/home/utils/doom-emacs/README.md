# Doom Emacs Testing Module

> **Purpose**: Test Doom Emacs **alongside** your regular Emacs setup without conflicts.
>
> **Use case**: Port journal features from your main Emacs config to evaluate Doom's workflow.

## Why This Approach?

### Safety First

Your current Emacs setup:
- ✅ Works perfectly for daily notes/journal
- ✅ Synced via Syncthing (important for data safety)
- ✅ Managed in Git at [github.com/waltharius/emacs](https://github.com/waltharius/emacs)
- ✅ Has complex custom functions you rely on

**Risk**: Installing Doom traditionally could overwrite `~/.emacs.d` → **Disaster**

**This module**: Installs Doom in **completely isolated directories**:
```
~/.emacs.d/               # Your regular Emacs (UNTOUCHED)
~/.config/doom-test/      # Doom config (init.el, config.el, packages.el)
~/.config/emacs-doom-test/# Doom installation (packages, cache)
```

## Directory Structure Explained

### DOOMDIR vs EMACSDIR

Doom Emacs uses **two separate directories**:

1. **DOOMDIR** (`~/.config/doom-test/`)
   - Your configuration files:
     - `init.el` - Which Doom modules to enable
     - `config.el` - Your personal settings
     - `packages.el` - Additional packages
     - `+journal.el` - Ported journal functions

2. **EMACSDIR** (`~/.config/emacs-doom-test/`)
   - Doom's installation:
     - Downloaded packages
     - Compiled bytecode
     - Cache and state files
     - Doom CLI (`bin/doom`)

**Why separate?**
- Config (`DOOMDIR`) = what you edit in Git
- Installation (`EMACSDIR`) = generated files, can be deleted/rebuilt

## Features Ported from Main Emacs

### Journal Creation

#### SPC n j - Create/Open Today's Journal
Ported from `my/denote-journal`:
- Creates `YYYYMMDDTHHmmss--YYYY-MM-DD-journal__journal.org`
- Includes well-being property (empty, fill manually)
- Smart spacing (one blank line between entries)
- Auto-saves immediately

#### SPC n J - Create Journal with Custom Date
Ported from `my/denote-journal-date`:
- For migrating old entries
- Same structure as daily journal
- Prompts for custom date via org-mode date picker

### Journal Structure (Exact Match)

```org
#+title:      YYYY-MM-DD Journal
#+date:       [YYYY-MM-DD Day HH:MM]
#+filetags:   :journal:
#+identifier: YYYYMMDDTHHmmss

:PROPERTIES:
:well-being:  
:END:

* Książenice (HH:MM)
```

**Critical**: Structure matches your main Emacs **exactly**!

### File Management

- **SPC n R** - Rename based on frontmatter (title/tags in file)
- **SPC n t** - Manage keywords/tags
- **SPC n l** - Add denote links
- **SPC n i** - Insert link to another note

### Well-being Tracking (Simplified)

- **SPC n w** - Add well-being score (1-10) to today's journal
- Stores in `:PROPERTIES:` drawer
- Optional keywords (e.g., `#śpiący #zła-pogoda`)

**Note**: Full well-being statistics module not ported yet (future).

## Installation

### Step 1: Add to flake.nix

Edit `flake.nix` at repository root:

```nix
{
  inputs = {
    # ... your existing inputs ...
    
    # ADD: Doom Emacs
    nix-doom-emacs-unstraightened = {
      url = "github:marienz/nix-doom-emacs-unstraightened";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    nix-doom-emacs-unstraightened,  # ADD
    ...
  } @ inputs: {
    # ... rest of config
  };
}
```

### Step 2: Update home.nix

Edit `users/marcin/home.nix`:

```nix
{
  imports = [
    # ... your existing imports ...
    ../../modules/home/utils/doom-emacs  # ADD
  ];

  # Enable Doom Emacs testing
  programs.doom-emacs-test.enable = true;

  # Optional: Customize directories
  # programs.doom-emacs-test.doomConfigDir = "${config.home.homeDirectory}/.config/doom-test";
  # programs.doom-emacs-test.doomInstallDir = "${config.home.homeDirectory}/.config/emacs-doom-test";

  # Your regular Emacs stays unchanged!
  home.packages = with pkgs; [
    emacs  # Regular Emacs (untouched)
    # ... other packages ...
  ];
}
```

### Step 3: Rebuild

```bash
sudo nixos-rebuild switch --flake ~/nixos#azazel  # or #sukkub
```

After rebuild, you'll see:
```
🎨 Doom Emacs (test) installed!
   Config dir:  /home/marcin/.config/doom-test
   Install dir: /home/marcin/.config/emacs-doom-test

📝 Usage:
   doom-emacs       → Launch Doom Emacs
   doom-test sync   → Sync packages (run after config changes)
   doom-test doctor → Check installation health

🗒️  Journal keybindings (in Doom):
   SPC n j  → Create/open today's journal
   SPC n J  → Create journal with custom date
   SPC n R  → Rename based on frontmatter
   SPC n t  → Manage tags
```

## Usage

### First Run

```bash
# Launch Doom Emacs
doom-emacs

# On first run, Doom will install packages automatically
# Wait for it to complete (~2-3 minutes)

# If needed, manually sync packages:
doom-test sync
```

### Daily Workflow

#### Create Journal (Same Notes Directory!)

```bash
# Launch Doom
doom-emacs

# In Doom:
SPC n j      # Create/open today's journal
```

This creates journal in `~/notes/` - **same directory as your regular Emacs**!

#### Verify Compatibility

Create journal in Doom, then open in regular Emacs:

```bash
# In Doom:
SPC n j  # Create journal

# Close Doom, open regular Emacs:
emacs ~/notes/YYYYMMDDTHHmmss--YYYY-MM-DD-journal__journal.org
```

File should look identical to your regular journal format!

### Doom CLI Tools

```bash
# Sync packages after editing config
doom-test sync

# Check for issues
doom-test doctor

# Upgrade Doom packages
doom-test upgrade

# Clean cache
doom-test clean
```

## Keybindings Reference

### Journal Functions

| Key       | Function                          | Description                       |
|-----------|-----------------------------------|-----------------------------------|
| `SPC n j` | `my/doom-journal`                 | Create/open today's journal       |
| `SPC n J` | `my/doom-journal-date`            | Create journal with custom date   |
| `SPC n w` | `my/doom-wellbeing-entry`         | Add well-being score to journal   |

### File Management

| Key       | Function                          | Description                       |
|-----------|-----------------------------------|-----------------------------------|
| `SPC n R` | `denote-rename-file-using-front-matter` | Rename based on title/tags  |
| `SPC n t` | `denote-rename-file-keywords`     | Manage keywords/tags              |
| `SPC n l` | `denote-add-links`                | Add links to current note         |
| `SPC n i` | `denote-link`                     | Insert link to another note       |
| `SPC n f` | `denote-open-or-create`           | Find note or create new           |

### Org-Mode (Local Leader)

| Key               | Function              | Description                |
|-------------------|-----------------------|----------------------------|
| `, t` (localleader) | `my/doom-insert-time` | Insert current time (HH:MM) |

## Customization

### Editing Config

All config files are in `~/.config/doom-test/`:

```bash
# Edit Doom config
vim ~/.config/doom-test/config.el

# Edit journal functions
vim ~/.config/doom-test/+journal.el

# After changes, sync packages:
doom-test sync
```

### Adding More Features

To port additional features from your main Emacs:

1. **Find function in** [`github.com/waltharius/emacs/modules/`](https://github.com/waltharius/emacs/tree/main/modules)
2. **Copy to** `~/.config/doom-test/+journal.el`
3. **Adjust keybindings** for Doom's leader key (`SPC`)
4. **Run** `doom-test sync`

### Example: Port Well-being Statistics

From your main Emacs `05d-denote-wellbeing.el`:

```elisp
;; Add to ~/.config/doom-test/+journal.el

(defun my/doom-wellbeing-stats ()
  "Show well-being statistics (7/30 days average)."
  (interactive)
  ;; ... copy function from main Emacs ...
  )

;; Add keybinding
(map! :leader
      :prefix "n"
      :desc "Well-being stats" "W" #'my/doom-wellbeing-stats)
```

## Troubleshooting

### Doom Not Finding Notes

**Check**: Org directory setting in `~/.config/doom-test/config.el`:

```elisp
(setq org-directory "~/notes/")
(setq denote-directory (expand-file-name "~/notes/"))
```

### Packages Not Installing

```bash
# Run Doom doctor
doom-test doctor

# Force clean and reinstall
doom-test clean
doom-test sync -u
```

### Conflicts with Regular Emacs

**Should never happen** - directories are isolated:
- Regular Emacs: `~/.emacs.d/`
- Doom Emacs: `~/.config/emacs-doom-test/`

If you see conflicts, check:
```bash
echo $DOOMDIR    # Should be empty in regular Emacs
echo $EMACSDIR   # Should be empty in regular Emacs
```

### Journal Structure Mismatch

If journal format doesn't match main Emacs:

1. **Compare files**:
   ```bash
   # From main Emacs
   cat ~/notes/20260105T123456--2026-01-05-journal__journal.org
   
   # From Doom
   cat ~/notes/20260105T143210--2026-01-05-journal__journal.org
   ```

2. **Check** `+journal.el` matches your main Emacs functions

3. **Report issue** if format differs

## Testing Checklist

Before committing to Doom:

- [ ] Launch Doom: `doom-emacs` works
- [ ] Create journal: `SPC n j` creates file in `~/notes/`
- [ ] Check format: Journal structure matches main Emacs
- [ ] Test from main Emacs: Open Doom-created journal in regular Emacs
- [ ] Test rename: `SPC n R` renames based on frontmatter
- [ ] Test tags: `SPC n t` manages keywords
- [ ] Test well-being: `SPC n w` adds score to journal
- [ ] Both Emacs run simultaneously without conflicts

## Migration Strategy

Once you're comfortable with Doom:

### Phase 1: Evaluation (Current)
- Use Doom for **new journals only**
- Keep main Emacs for **existing notes**
- Compare workflows over 2-4 weeks

### Phase 2: Feature Parity
- Port remaining features:
  - Well-being statistics
  - Cockpit/dashboard
  - Transient menus
  - Project management
  - Hugo export

### Phase 3: Decision
If Doom wins:
- Move config to `~/.config/doom/` (permanent location)
- Keep `~/.emacs.d/` as backup for 3 months
- Update Syncthing to sync `~/.config/doom/`

If regular Emacs wins:
- Keep using it!
- Delete Doom test directories
- Remove from `home.nix`

## Advantages of This Approach

1. **Zero Risk**: Regular Emacs completely untouched
2. **Same Data**: Both use `~/notes/` - journals work in both
3. **Gradual Learning**: Test Doom without pressure
4. **Easy Rollback**: Just `programs.doom-emacs-test.enable = false;`
5. **Declarative**: All config in Git, reproducible

## Files in This Module

```
modules/home/utils/doom-emacs/
├── default.nix           # Module import
├── doom-emacs.nix         # Main module (NixOS configuration)
├── journal-functions.el   # Ported Emacs Lisp functions
└── README.md              # This file
```

## Resources

- **Your main Emacs config**: [github.com/waltharius/emacs](https://github.com/waltharius/emacs)
- **Your NixOS config**: [github.com/waltharius/nixos](https://github.com/waltharius/nixos)
- **Doom Emacs docs**: [docs.doomemacs.org](https://docs.doomemacs.org)
- **Denote manual**: [protesilaos.com/emacs/denote](https://protesilaos.com/emacs/denote)

## Questions?

Compare ported functions with originals:
- `journal-functions.el` (this module) ↔️ `05-denote-functions.el` (main Emacs)
- `+journal.el` keybindings ↔️ `06-keybindings.el` (main Emacs)

If behavior differs, check both files to ensure port is accurate.
