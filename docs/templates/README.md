# Org-Mode Templates

These are example templates for Neovim org-mode journal and note creation.

## Setup

Copy these templates to your notes directory:

```bash
mkdir -p ~/notes/templates
cp ~/nixos/docs/templates/*.org ~/notes/templates/
```

## Available Templates

### `journal.org`
Used when creating a **new journal file** for a day.

**Available placeholders:**
- `{{DATE}}` - Date in YYYY-MM-DD format
- `{{WEEKDAY}}` - Day name (e.g., Friday)
- `{{TIME}}` - Current time HH:MM
- `{{IDENTIFIER}}` - Denote identifier (timestamp)

### `journal-entry.org`
Used when **adding an entry** to an existing journal.

**Available placeholders:**
- `{{TIME}}` - Current time HH:MM

### `note.org`
Used when creating a **general note** with `Space n n`.

**Available placeholders:**
- `{{TITLE}}` - Note title
- `{{DATE}}` - Date in YYYY-MM-DD format
- `{{TAGS}}` - Tags (colon-separated)
- `{{IDENTIFIER}}` - Denote identifier (timestamp)

## Customization

**No rebuild needed!** Just edit the files in `~/notes/templates/` and changes take effect immediately.

### Example: Custom Journal Template

```org
#+title: {{DATE}} Daily Journal
#+date: [{{DATE}} {{WEEKDAY}}]
#+filetags: :journal:daily:
#+identifier: {{IDENTIFIER}}
:PROPERTIES:
:mood:
:energy:
:gratitude:
:END:

* {{TIME}} Morning Reflection

** What I'm grateful for

** Today's goals

** Notes

```

### Example: Custom Note Template

```org
#+title: {{TITLE}}
#+date: [{{DATE}}]
#+filetags: :{{TAGS}}:
#+identifier: {{IDENTIFIER}}
:PROPERTIES:
:project:
:status: draft
:END:

* Overview

* Details

* References

```

## Fallback Behavior

If template files don't exist in `~/notes/templates/`, the system uses built-in defaults from the Lua configuration. This ensures everything works even without custom templates.

## Emacs Compatibility

These templates follow the Denote format used in Emacs:
- Lowercase `#+title:`, `#+date:`, etc. (standard org-mode)
- `#+identifier:` field for Denote compatibility
- Filename format: `YYYYMMDDTHHMMSS--title__tags.org`
