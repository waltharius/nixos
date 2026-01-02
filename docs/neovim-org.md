# Neovim Org-Mode Module Documentation

## Overview

This is an **optional, modular** extension for Neovim that adds org-mode and denote-style note-taking capabilities. It's designed to work seamlessly alongside Emacs without modifying your existing org files.

### Key Features

- ✅ **100% Emacs-compatible** - No changes to your org file format
- ✅ **Denote-style naming** - `YYYYMMDDTHHMMSS--title__tags.org`
- ✅ **Journal workflow** - Exactly like your Emacs setup
- ✅ **Spell checking** - English + Polish support
- ✅ **Easy to disable** - Just comment one line and rebuild
- ✅ **No impact on code editing** - Only loads for org files

---

## Installation

### Enable the Module

Add this import to your `modules/utils/neovim.nix`:

```nix
# At the top of the file with other imports
imports = [
  ./neovim-org.nix  # Optional: Org-mode support
];
```

### Disable the Module

To disable (e.g., on servers or child's laptop):

```nix
imports = [
  # ./neovim-org.nix  # Disabled
];
```

Then rebuild:
```bash
cd ~/nixos
sudo nixos-rebuild switch --flake .
```

---

## Workflow Guide

### Daily Journaling

#### Today's Journal (`<leader>nj` or `Space n j`)

**First entry of the day:**
- Creates: `20260102T094530--2026-01-02-journal__journal.org`
- Includes wellbeing template
- Cursor positioned at notes section

**Subsequent entries:**
- Opens existing journal
- Adds new time-stamped section
- Example: `* 14:30 Entry`

#### Past Date Journal (`<leader>nJ` or `Space n J`)

- Prompts for date: `2023-03-24`
- Creates: `20230324T000000--2023-03-24-journal__journal.org`
- Note the `T000000` timestamp for past dates
- If journal exists, opens it instead

### General Notes

#### Create New Note (`<leader>nn` or `Space n n`)

1. Prompts for title: `My Important Note`
2. Prompts for tags: `nixos learning`
3. Creates: `20260102T094530--my-important-note__nixos_learning.org`

---

## File Format

### Journal Template

```org
#+TITLE: 2026-01-02 Journal
#+DATE: [2026-01-02 Thursday]
#+FILETAGS: :journal:

* 09:45 Entry

** Wellbeing
Mood: 
Energy: 
Focus: 

** Notes

```

### Regular Note Template

```org
#+TITLE: My Note Title
#+DATE: [2026-01-02 Thursday]
#+FILETAGS: :tag1:tag2:

* Notes

```

---

## Keybindings

### Notes Operations (Leader = Space)

| Keybinding | Function | Description |
|------------|----------|-------------|
| `<leader>nj` | `Journal_today()` | Today's journal (create or add entry) |
| `<leader>nJ` | `Journal_past_date()` | Journal for specific past date |
| `<leader>nn` | `Create_note()` | Create new note with tags |
| `<leader>ns` | Toggle spell | Toggle spell checking |
| `<leader>na` | Org agenda | Open org-agenda (if used) |
| `<leader>nc` | Org capture | Org-capture templates |

### Spell Checking

| Keybinding | Function | Description |
|------------|----------|-------------|
| `z=` | Suggestions | Show spelling suggestions |
| `zg` | Add to dict | Add word to dictionary |
| `zw` | Mark wrong | Mark word as misspelled |
| `]s` | Next | Jump to next misspelled word |
| `[s` | Previous | Jump to previous misspelled word |

### Org-Mode Navigation (in org files)

| Keybinding | Function | Description |
|------------|----------|-------------|
| `gj` / `gk` | Move | Navigate visible lines (respects wrapping) |
| `TAB` | Fold/unfold | Toggle heading visibility |
| `<CR>` | Follow link | Open org link under cursor |
| `cit` | Change text | Change TODO state |

---

## Spell Checking

### Automatic Activation

Spell checking is automatically enabled for all `.org` files with:
- **English (US)** - Primary
- **Polish** - Secondary

### Manual Toggle

- Enable: `<leader>ns` or `:set spell`
- Disable: `<leader>ns` or `:set nospell`

### Adding Words to Dictionary

1. Place cursor on word
2. Press `zg` to add to personal dictionary
3. Dictionary location: `~/.local/share/nvim/site/spell/en.utf-8.add`

---

## Compatibility with Emacs

### What's Preserved

✅ **File naming format** - Exact denote format
✅ **Org syntax** - Headers, properties, tags
✅ **TODO keywords** - TODO, IN-PROGRESS, WAITING, DONE, CANCELED
✅ **Timestamps** - All date formats
✅ **Links** - `[[file:note.org]]` and `[[file:note.org::*Heading]]`
✅ **Whitespace** - No auto-formatting changes

### What's Different

⚠️ **No calendar view** - Use telescope instead (`<leader>ff`)
⚠️ **No transient menus** - Direct keybindings instead
⚠️ **Basic export** - Use Emacs for PDF/HTML export
⚠️ **No org-transclusion** - Use splits or copy-paste

### Workflow Recommendation

**Use Neovim for:**
- 📝 Writing and editing notes
- ⚡ Quick journal entries
- 🔍 Searching notes (telescope)
- ⌨️ Fast text manipulation (vim motions)

**Use Emacs for:**
- 📅 Calendar visualization
- 📊 Org-agenda workflows
- 📤 PDF/HTML export
- 🔗 Org-transclusion

---

## Examples

### Daily Workflow

```bash
# Morning journal
<leader>nj
# Type your entry, save with :w

# Later in the day, add another entry
<leader>nj
# New time section is added automatically

# Create a note about something you learned
<leader>nn
Title: NixOS Flake Inputs
Tags: nixos learning

# Search for notes
<leader>ff
# Type: journal 2026
```

### Past Date Journaling

```bash
# Catch up on yesterday's journal
<leader>nJ
Date: 2026-01-01
# File created: 20260101T000000--2026-01-01-journal__journal.org
```

### Spell Checking Workflow

```bash
# Writing in Polish
Dzisiaj jest piękny dzień
# Typo appears underlined

# Press z= on underlined word
# Select correct spelling from suggestions
# Or press zg to add to dictionary
```

---

## File Locations

### Notes Directory
```
~/notes/
├── 20260102T094530--my-note__tag1_tag2.org
├── 20260102T153000--2026-01-02-journal__journal.org
├── 20260101T000000--2026-01-01-journal__journal.org
└── inbox.org
```

### Configuration
```
~/nixos/
├── modules/utils/
│   ├── neovim.nix          # Main config
│   └── neovim-org.nix      # Org-mode module (optional)
└── docs/
    └── neovim-org.md       # This file
```

---

## Troubleshooting

### Org files not opening correctly

**Check if module is loaded:**
```vim
:echo exists('*Journal_today')
" Should return 1 if loaded
```

**Verify orgmode plugin:**
```vim
:Lazy
" Search for 'orgmode' - should show as loaded
```

### Spell checking not working

**Check spell settings:**
```vim
:set spell?
:set spelllang?
" Should show: spell spelllang=en_us,pl
```

**Install dictionaries manually:**
```bash
nix-shell -p aspell aspellDicts.en aspellDicts.pl
```

### Journal not creating files

**Check notes directory:**
```bash
ls -la ~/notes/
# Should exist and be writable
```

**Create if missing:**
```bash
mkdir -p ~/notes
```

### Keybindings not working

**Check leader key:**
```vim
:echo mapleader
" Should show a space
```

**Test binding manually:**
```vim
:lua Journal_today()
```

---

## Advanced Usage

### Custom Templates

To modify templates, edit the Lua functions in `neovim-org.nix`:

```lua
local template = {
  '#+TITLE: ' .. title,
  '#+DATE: [' .. date .. ']',
  '#+FILETAGS: :' .. tags .. ':',
  '',
  '* Your custom section',
  '',
}
```

### Additional Tags

You can add wellbeing status or custom properties directly in files:

```org
#+TITLE: 2026-01-02 Journal
#+DATE: [2026-01-02 Thursday]
#+FILETAGS: :journal:
#+MOOD: happy
#+ENERGY: high
#+FOCUS: excellent
```

### Integration with Telescope

Search notes by content:
```vim
<leader>fg
" Type search term
" Results show matching lines from all org files
```

Find notes by filename:
```vim
<leader>ff
" Type date or tag
" Fuzzy matches your notes
```

---

## Migration Guide

### From Pure Emacs

1. **Backup your notes:**
   ```bash
   cp -r ~/notes ~/notes.backup
   ```

2. **Enable the module** (see Installation above)

3. **Test with new note:**
   ```vim
   nvim
   <leader>nn
   ``` 

4. **Verify compatibility:**
   - Open new note in Emacs
   - Check format is identical
   - Verify tags and properties work

5. **Start using both editors interchangeably!**

### Disabling for Specific Machines

**Server configuration:**
```nix
# In your server's configuration.nix
imports = [
  ./modules/utils/neovim.nix
  # Note: NOT importing neovim-org.nix
];
```

**Child's laptop:**
```nix
# In child's home-manager config
imports = [
  ./modules/utils/neovim.nix
  # Note: NOT importing neovim-org.nix
];
```

---

## FAQ

**Q: Will this change my existing org files?**
A: No. The module is read-only for existing files. It only creates new files in the denote format.

**Q: Can I use this alongside Emacs?**
A: Yes! That's the whole point. Edit in Neovim, use Emacs for agenda/export.

**Q: What if I don't like it?**
A: Just comment out the import line and rebuild. No traces left.

**Q: Does this work offline?**
A: Yes, everything is local. No internet required.

**Q: Can I customize the templates?**
A: Yes, edit the Lua functions in `neovim-org.nix`.

**Q: Where are spell dictionaries stored?**
A: `~/.local/share/nvim/site/spell/`

---

*Last updated: 2026-01-02*
