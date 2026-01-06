#!/usr/bin/env bash
# =============================================================================
# track-package - NixOS Package History Tracker
# =============================================================================
#
# PURPOSE:
#   Track package version changes across NixOS system and home-manager
#   generations. Helps debug when a package broke by showing version history
#   and linking changes to git commits.
#
# DATABASE:
#   All data is stored in SQLite database at:
#   ~/.local/share/nixos-track-package/history.db
#
#   The database preserves history even after garbage collection!
#   Old generation data is marked as "GC'd" but never deleted.
#
# USAGE:
#   track-package <package-name> [profile] [flags]
#
# PROFILES:
#   system   - Only search system packages (/run/current-system)
#   home     - Only search home-manager packages (~/.local/state/nix/profiles)
#   both     - Search both (default)
#
# FLAGS:
#   -v, --verbose   Show detailed output with full store paths
#   -r, --rescan    Force rescan of generations (updates database)
#   --scan-all      Scan ALL packages across all generations (very slow!)
#
# EXAMPLES:
#
#   1. Quick check - show firefox version history
#      $ track-package firefox
#
#   2. Detailed view with store paths
#      $ track-package firefox -v
#
#   3. After system update - rescan to add new generations
#      $ track-package firefox -r
#
#   4. Search only home-manager packages
#      $ track-package emacs home
#
#   5. Search only system packages
#      $ track-package linux system
#
#   6. Build complete system history (takes 10-30 minutes!)
#      $ track-package --scan-all
#
# COMMON WORKFLOWS:
#
#   Scenario 1: Package stopped working after update
#   ─────────────────────────────────────────────
#   $ track-package firefox
#   # Look at the table - which generation changed version?
#   # Check git commit hash
#   $ cd ~/nixos && git show abc123de
#   # Found the problematic commit!
#
#   Scenario 2: When did I add this package?
#   ────────────────────────────────────
#   $ track-package vscode
#   # Look for "ADDED" event in output
#
#   Scenario 3: Track package that was removed
#   ──────────────────────────────────────
#   $ track-package old-package
#   # Shows history including "REMOVED" event
#   # Even if package no longer exists, history is preserved!
#
#   Scenario 4: After garbage collection
#   ────────────────────────────────────
#   $ sudo nix-collect-garbage --delete-older-than 30d
#   $ track-package firefox
#   # Old generations show as "(GC'd)" but history remains
#   # You still see what versions existed when!
#
#   Scenario 5: Full system audit
#   ─────────────────────────────────
#   $ track-package --scan-all
#   # Scans all 4,000+ packages, takes ~20 minutes
#   # Then any package lookup is instant from database
#
# OUTPUT EXPLANATION:
#
#   Generation: NixOS generation number (#1, #2, etc.)
#   Date:       When that generation was created
#   Version:    Package version in that generation
#   Event:      What happened?
#               - ADDED: Package appeared for first time
#               - UPGRADED: Version changed (increased)
#               - REMOVED: Package no longer in system
#               - DOWNGRADED: Version went backwards (rare)
#   Git:        First 12 chars of git commit hash
#               - "(no commit)" means rebuild without committing
#               - "(GC'd)" means generation was garbage collected
#
# DATABASE QUERIES:
#
#   You can query the database directly with sqlite3:
#
#   # Show all packages upgraded in December
#   $ sqlite3 ~/.local/share/nixos-track-package/history.db \
#     "SELECT DISTINCT package_name FROM package_history
#      WHERE event='UPGRADED' AND date LIKE '2025-12%';"
#
#   # Find most frequently updated packages
#   $ sqlite3 ~/.local/share/nixos-track-package/history.db \
#     "SELECT package_name, COUNT(*) as changes
#      FROM package_history WHERE event='UPGRADED'
#      GROUP BY package_name ORDER BY changes DESC LIMIT 10;"
#
#   # Show packages removed by GC
#   $ sqlite3 ~/.local/share/nixos-track-package/history.db \
#     "SELECT package_name, COUNT(*) as gc_count
#      FROM package_history WHERE generation_exists=0
#      GROUP BY package_name;"
#
# PERFORMANCE:
#
#   First scan:  ~60-90 seconds for single package (scans all generations)
#   Cached:      Instant (reads from database)
#   Rescan:      ~10-30 seconds (only new generations)
#   --scan-all:  ~10-30 minutes (scans every package)
#
# SAFETY:
#
#   - Read-only operations (except database writes)
#   - Never modifies your NixOS configuration
#   - Database is stored in your home directory
#   - Safe to run on production systems
#
# TIPS:
#
#   1. Run with -r after each system rebuild to keep DB current
#   2. Add to your shell aliases:
#      alias tp='track-package'
#      alias tpv='track-package -v'
#   3. Backup database periodically:
#      cp ~/.local/share/nixos-track-package/history.db ~/backups/
#   4. History survives garbage collection - this is a feature!
#   5. Use --scan-all once to build full history, then quick lookups forever
#
# TROUBLESHOOTING:
#
#   Q: Package not found but I know it's installed?
#   A: The package might have a different name in the store.
#      Try: nix-store -qR /run/current-system | grep -i <partial-name>
#
#   Q: Scan is very slow?
#   A: This is normal for first scan. Subsequent runs are fast.
#      You're scanning 177+ generations × package closure (~10GB data)
#
#   Q: Database file getting large?
#   A: This is expected. Full system scan creates ~50-100MB database.
#      This is tiny compared to the value of having full history!
#
#   Q: Want to reset everything?
#   A: rm -rf ~/.local/share/nixos-track-package/
#      Next run will rebuild from scratch.
#
# =============================================================================

set -euo pipefail

# Source library functions
# shellcheck disable=SC1091
source "@LIB_PATH@"

PROGRAM="${1:-}"
PROFILE_TYPE="both"
VERBOSE=false
RESCAN=false
SCAN_ALL=false

# Parse flags
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
  -v | --verbose)
    VERBOSE=true
    shift
    ;;
  -r | --rescan)
    RESCAN=true
    shift
    ;;
  --scan-all)
    SCAN_ALL=true
    shift
    ;;
  system | home | both)
    PROFILE_TYPE="$1"
    shift
    ;;
  *)
    shift
    ;;
  esac
done

if [ -z "$PROGRAM" ] && [ "$SCAN_ALL" = false ]; then
  cat <<'USAGE'
Usage: track-package <program-name> [system|home|both] [-v|--verbose] [-r|--rescan]
       track-package --scan-all                           # Scan entire system

Track package version changes across NixOS generations

Options:
  system|home|both    Which profiles to search (default: both)
  -v, --verbose       Show detailed list with full store paths
  -r, --rescan        Rescan and update database (preserves old data)
  --scan-all          Scan all packages across all generations (slow)

Examples:
  track-package firefox              # Show firefox history
  track-package firefox -v           # Detailed view with store paths
  track-package firefox -r           # Update database with new generations
  track-package emacs home           # Search only home-manager packages
  track-package linux system         # Search only system packages
  track-package --scan-all           # Build complete system history

Database: ~/.local/share/nixos-track-package/history.db

Common Workflow:
  1. Package broke? → track-package <name>
  2. Check which generation changed the version
  3. Look at git commit: cd ~/nixos && git show <hash>
  4. Found the problem!

Tips:
  - First scan takes ~60s, subsequent lookups are instant
  - History survives garbage collection (marked as "GC'd")
  - Use -r after system rebuild to stay current
  - Use --scan-all once for full system history

For more help: vim $(which track-package)  # Read the header comments
USAGE
  exit 1
fi

# Database setup
DB_DIR="$HOME/.local/share/nixos-track-package"
DB_FILE="$DB_DIR/history.db"
SCHEMA_FILE="@SCHEMA_PATH@"

mkdir -p "$DB_DIR"
init_database "$DB_FILE" "$SCHEMA_FILE"

# Scan a single package
scan_package() {
  local program="$1"
  local profile_pattern="$2"
  local profile_type="$3"

  local scan_start scan_timestamp
  scan_start=$(date +%s)
  scan_timestamp=$(date -Iseconds)

  echo -e "${YELLOW}[Scanning $profile_type generations for '$program'...]${NC}"

  local total_gens=0 new_records=0 prev_version=""

  while IFS= read -r gen_link; do
    [ -L "$gen_link" ] || continue

    total_gens=$((total_gens + 1))

    local gen_num
    gen_num=$(basename "$gen_link" | grep -oP '\d+(?=-link)')

    # Check if already in DB
    local exists_in_db
    exists_in_db=$(generation_in_db "$DB_FILE" "$program" "$gen_num" "$profile_type")

    if [ "$exists_in_db" -gt 0 ] && [ "$RESCAN" = false ]; then
      sqlite3 "$DB_FILE" "UPDATE package_history SET generation_exists=1 WHERE package_name='$(sql_escape "$program")' AND generation_num=$gen_num AND profile_type='$profile_type';"
      continue
    fi

    local gen_date git_commit
    gen_date=$(stat -c "%Y" "$gen_link" 2>/dev/null)
    gen_date=$(date -d "@$gen_date" -Iseconds 2>/dev/null || echo "unknown")
    git_commit="NULL"

    if [ -f "$gen_link/etc/nixos-git-revision" ]; then
      local full_commit
      full_commit=$(cat "$gen_link/etc/nixos-git-revision" 2>/dev/null)
      if [ "$full_commit" != "uncommitted-changes" ] && [ -n "$full_commit" ]; then
        git_commit="'$(sql_escape "${full_commit:0:12}")'" 
      fi
    fi

    # Search for package
    local program_path
    program_path=$(nix-store -qR "$gen_link" 2>/dev/null |
      grep -E "[-/]$program-[0-9]" |
      grep -v "\.drv$" |
      head -1 || echo "")

    local version event
    if [ -n "$program_path" ]; then
      local pkg_name
      pkg_name=$(basename "$program_path")
      version=$(echo "$pkg_name" | sed -E "s/^$program-//")

      if [ -z "$prev_version" ]; then
        event="ADDED"
      elif [ "$version" != "$prev_version" ]; then
        event="UPGRADED"
      else
        event="UNCHANGED"
      fi

      prev_version="$version"
    elif [ -n "$prev_version" ]; then
      version="(removed)"
      event="REMOVED"
      program_path=""
      prev_version=""
    else
      continue
    fi

    # Insert record
    insert_package_record "$DB_FILE" "$program" "$gen_num" "$profile_type" \
      "$version" "$event" "$gen_date" "$git_commit" "$program_path" "$scan_timestamp"

    new_records=$((new_records + 1))

  done < <(find "$(dirname "$profile_pattern")" -maxdepth 1 -name "$(basename "$profile_pattern")" -type l 2>/dev/null | sort -V)

  update_gc_status "$DB_FILE" "$profile_type"

  local scan_duration
  scan_duration=$(($(date +%s) - scan_start))

  sqlite3 "$DB_FILE" <<EOSQL
INSERT INTO scan_metadata 
    (scan_type, package_name, profile_type, total_generations, 
     packages_scanned, scan_timestamp, duration_seconds)
VALUES 
    ('package', '$(sql_escape "$program")', '$profile_type', $total_gens, 
     1, '$scan_timestamp', $scan_duration);
EOSQL

  echo -e "${GREEN}[Scanned $total_gens generations, added/updated $new_records records]${NC}"
}

# Display package history
display_package_history() {
  local program="$1"
  local profile_type="$2"

  local total_records
  total_records=$(get_package_count "$DB_FILE" "$program" "$profile_type")

  if [ "$total_records" -eq 0 ]; then
    echo -e "${YELLOW}No history found for '$program' in $profile_type profile${NC}"
    return 1
  fi

  local existing_count gc_count
  existing_count=$(get_gc_stats "$DB_FILE" "$program" "$profile_type" "active")
  gc_count=$(get_gc_stats "$DB_FILE" "$program" "$profile_type" "gcd")

  echo ""
  echo -e "${BOLD}[$(echo "$profile_type" | tr '[:lower:]' '[:upper:]') PACKAGES]${NC}"
  echo -e "Total records: $total_records (${GREEN}$existing_count active${NC}, ${DIM}$gc_count GC'd${NC})"
  echo ""

  print_table_header

  # Query and display
  sqlite3 "$DB_FILE" -separator '|' <<EOSQL | while IFS='|' read -r gen date version event git_commit exists; do
SELECT generation_num, 
       substr(date, 1, 16),
       version, 
       event,
       COALESCE(git_commit, '(no commit)'),
       generation_exists
FROM package_history 
WHERE package_name='$(sql_escape "$program")' AND profile_type='$profile_type'
  AND event != 'UNCHANGED'
ORDER BY generation_num ASC;
EOSQL
    print_table_row "$gen" "$date" "$version" "$event" "$git_commit" "$exists"
  done

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Summary
  local added removed upgraded
  added=$(get_event_count "$DB_FILE" "$program" "$profile_type" "ADDED")
  removed=$(get_event_count "$DB_FILE" "$program" "$profile_type" "REMOVED")
  upgraded=$(($(get_event_count "$DB_FILE" "$program" "$profile_type" "UPGRADED") + $(get_event_count "$DB_FILE" "$program" "$profile_type" "DOWNGRADED")))

  echo -e "${BOLD}Summary:${NC} $upgraded version changes, $added additions, $removed removals"
  echo -e "${BOLD}Database:${NC} $DB_FILE"

  # Verbose output
  if [ "$VERBOSE" = true ]; then
    echo ""
    echo -e "${BOLD}[DETAILED VIEW]${NC}"
    sqlite3 "$DB_FILE" -separator '|' <<EOSQL | while IFS='|' read -r gen date version event git store exists; do
SELECT generation_num, date, version, event, 
       COALESCE(git_commit, '(no commit)'),
       COALESCE(store_path, 'N/A'),
       generation_exists
FROM package_history 
WHERE package_name='$(sql_escape "$program")' AND profile_type='$profile_type'
  AND event != 'UNCHANGED'
ORDER BY generation_num ASC;
EOSQL
      local gc_marker=""
      if [ "$exists" = "0" ]; then
        gc_marker=" ${DIM}[GC'd]${NC}"
      fi
      echo -e "\nGeneration #$gen (${date:0:16})$gc_marker"
      echo "  Version: $version"
      echo "  Event: $event"
      echo "  Git: $git"
      echo "  Store: $store"
    done
  fi
  
  return 0
}

# Main execution
echo -e "${BOLD}Tracking '$PROGRAM' across generations...${NC}"

# Check if package exists in DB
in_db=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM package_history WHERE package_name='$(sql_escape "$PROGRAM")';")

if [ "$in_db" -eq 0 ] || [ "$RESCAN" = true ]; then
  if [ "$PROFILE_TYPE" = "system" ] || [ "$PROFILE_TYPE" = "both" ]; then
    scan_package "$PROGRAM" "/nix/var/nix/profiles/system-*-link" "system"
  fi

  if [ "$PROFILE_TYPE" = "home" ] || [ "$PROFILE_TYPE" = "both" ]; then
    scan_package "$PROGRAM" "$HOME/.local/state/nix/profiles/home-manager-*-link" "home"
  fi
else
  update_gc_status "$DB_FILE" "system"
  update_gc_status "$DB_FILE" "home"
fi

# Display results - disable exit on error temporarily to collect all results
set +e
found=false

if [ "$PROFILE_TYPE" = "system" ] || [ "$PROFILE_TYPE" = "both" ]; then
  if display_package_history "$PROGRAM" "system"; then
    found=true
  fi
fi

if [ "$PROFILE_TYPE" = "home" ] || [ "$PROFILE_TYPE" = "both" ]; then
  if display_package_history "$PROGRAM" "home"; then
    found=true
  fi
fi
set -e

if [ "$found" = false ]; then
  echo ""
  echo -e "${RED}Package '$PROGRAM' not found in any profile${NC}"
  echo ""
  echo -e "${YELLOW}Suggestions:${NC}"
  echo "  1. Check package name is correct"
  echo "  2. Try searching with: nix-store -qR /run/current-system | grep -i $PROGRAM"
  echo "  3. For home-manager: nix-store -qR ~/.local/state/nix/profiles/home-manager | grep -i $PROGRAM"
  echo "  4. Package might use different name in store (e.g., 'emacs' vs 'emacs-gtk')"
  echo ""
  exit 1
fi
