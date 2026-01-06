# track-package - NixOS Package History Tracker

Track package version changes across all your NixOS generations with persistent historical database.

## Quick Start

```bash
# Show firefox version history
track-package firefox

# Detailed view with store paths
track-package firefox -v

# After system update
track-package firefox -r
```

## Features

- 📊 **Track version changes** across all generations
- 💾 **Persistent SQLite database** - history survives GC
- 🔍 **Git commit tracking** - correlate with your nixos repo
- ⚡ **Fast lookups** - instant after first scan
- 🎨 **Color-coded output** - easy to scan visually
- 🏠 **Dual profile support** - system and home-manager

## Common Use Cases

### Debugging: Package broke after update

```bash
$ track-package firefox
# Output shows version changed in generation #84
# Git commit: c92f6e1d

$ cd ~/nixos && git show c92f6e1d
# Found the problematic change!
```

### Research: When did I install this?

```bash
$ track-package vscode
# Look for "ADDED" event with date
```

### Audit: What happened during GC?

```bash
$ track-package some-package
# Generations marked "(GC'd)" show historical data
# even though generations no longer exist!
```

## Output Explained

```
Gen   │ Date                │ Version              │ Event     │ Git / Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 #45  │ 2025-11-15 14:23   │ 119.0.1              │ ADDED     │ a3f9c21b
 #52  │ 2025-11-22 09:15   │ 120.0.0              │ UPGRADED  │ b7e4d39a
 #63  │ 2025-12-01 16:47   │ 121.0.1              │ UPGRADED  │ (no commit)
```

- **Gen**: Generation number
- **Date**: When generation was created  
- **Version**: Package version in that generation
- **Event**: What happened (ADDED/UPGRADED/REMOVED)
- **Git**: First 12 chars of commit hash

## Git Commit Tracking

To enable git commit tracking, add this to your `flake.nix` or `configuration.nix`:

```nix
{
  # For flake-based configs (flake.nix)
  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        {
          system.configurationRevision = 
            if (self ? rev) 
            then self.rev 
            else "uncommitted-changes";
        }
        # ... your other modules
      ];
    };
  };
}

# For traditional configs (configuration.nix)
system.configurationRevision = 
  pkgs.lib.mkIf (self ? rev) self.rev;
```

**Note**: Git commit hash is stored as metadata, not in the store path. This means:
- ✅ No disk space duplication
- ✅ Only ~50 bytes per generation
- ✅ Nix deduplication still works normally

## Database Location

All data stored in: `~/.local/share/nixos-track-package/history.db`

Direct SQL queries supported:

```bash
# Most updated packages
sqlite3 ~/.local/share/nixos-track-package/history.db \
  "SELECT package_name, COUNT(*) FROM package_history 
   WHERE event='UPGRADED' GROUP BY package_name 
   ORDER BY COUNT(*) DESC LIMIT 10;"

# Packages upgraded in specific month
sqlite3 ~/.local/share/nixos-track-package/history.db \
  "SELECT DISTINCT package_name FROM package_history 
   WHERE event='UPGRADED' AND date LIKE '2026-01%';"
```

## Usage Examples

```bash
# Basic usage
track-package firefox

# Detailed view with full store paths
track-package firefox -v

# Force rescan (after system rebuild)
track-package firefox -r

# Search only system packages
track-package linux system

# Search only home-manager packages
track-package emacs home

# Scan all packages (takes 10-30 minutes!)
track-package --scan-all
```

## Performance

- **First scan**: 60-90 seconds (scans all generations)
- **Cached**: Instant (reads from database)
- **Rescan**: 10-30 seconds (only new generations)
- **Full scan** (`--scan-all`): 10-30 minutes (all 4000+ packages)

## Tips

1. **Run after each rebuild**: `track-package firefox -r`
2. **Shell alias**: Add to your shell config:
   ```bash
   alias tp='track-package'
   alias tpv='track-package -v'
   alias tpr='track-package -r'
   ```
3. **Backup database**: `cp ~/.local/share/nixos-track-package/history.db ~/backups/`
4. **One-time full scan**: `track-package --scan-all` (then all lookups are instant)
5. **History survives GC**: Old generations are marked "(GC'd)" but data remains

## Safety

- ✅ Read-only operations on your system
- ✅ Never modifies NixOS configuration
- ✅ Database stored in home directory
- ✅ Safe for production systems
- ✅ No disk space duplication

## Troubleshooting

### Package not found

```bash
# Package might have different name in store
nix-store -qR /run/current-system | grep -i <partial-name>

# For home-manager packages
nix-store -qR ~/.local/state/nix/profiles/home-manager | grep -i <partial-name>
```

### Scan is slow

This is normal for first run. The tool scans 100+ generations × package closure (~10GB data).
Subsequent lookups are instant from database.

### Database getting large

A full system scan creates ~50-100MB database. This is tiny compared to the value of having
complete package history! The database is highly compressed and indexed.

### Reset everything

```bash
rm -rf ~/.local/share/nixos-track-package/
# Next run will rebuild from scratch
```

## Technical Details

### Database Schema

```sql
-- Package history table
package_history (
    package_name,        -- Package name (e.g., "firefox")
    generation_num,      -- Generation number
    profile_type,        -- "system" or "home"
    version,             -- Version string
    event,               -- ADDED/UPGRADED/REMOVED
    date,                -- ISO timestamp
    git_commit,          -- Git commit hash (12 chars)
    store_path,          -- Full /nix/store path
    generation_exists,   -- 0=GC'd, 1=exists
    scan_timestamp       -- When scanned
);

-- Scan metadata table
scan_metadata (
    scan_type,           -- "package" or "full"
    package_name,        -- Package scanned
    profile_type,        -- "system" or "home"
    total_generations,   -- Number of generations scanned
    packages_scanned,    -- Number of packages
    scan_timestamp,      -- When scan occurred
    duration_seconds     -- How long it took
);
```

### Files

```
packages/track-package/
├── default.nix         # Nix package definition
├── track-package.sh    # Main executable script
├── lib.sh             # Helper functions
├── schema.sql         # Database schema
└── README.md          # This file
```

### How It Works

1. **Scan**: Walks through all generations, queries nix-store for package versions
2. **Store**: Saves version history in SQLite database
3. **Cache**: Subsequent lookups read from database (instant)
4. **GC tracking**: Updates generation_exists flag when generations are collected
5. **Git correlation**: Reads `/etc/nixos-git-revision` from each generation

## License

MIT

## Author

Part of the waltharius/nixos repository.
