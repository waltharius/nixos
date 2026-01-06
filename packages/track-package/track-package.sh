#!/usr/bin/env bash
set -euo pipefail

# Source library functions
# shellcheck source=lib.sh
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
  echo "Usage: track-package <program-name> [system|home|both] [-v|--verbose] [-r|--rescan]"
  echo "       track-package --scan-all                           # Scan entire system"
  echo ""
  echo "Options:"
  echo "  system|home|both    Which profiles to search (default: both)"
  echo "  -v, --verbose       Show detailed list with full store paths"
  echo "  -r, --rescan        Rescan and update database (preserves old data)"
  echo "  --scan-all          Scan all packages across all generations (slow)"
  echo ""
  echo "Examples:"
  echo "  track-package firefox              # Show firefox history"
  echo "  track-package firefox -v           # Detailed view"
  echo "  track-package firefox -r           # Update database"
  echo "  track-package --scan-all           # Build complete system history"
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
    echo -e "${YELLOW}No history found for '$program' in $profile_type${NC}"
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

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

# Display results
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

if [ "$found" = false ]; then
  echo ""
  echo -e "${RED}Package '$PROGRAM' not found in any profile${NC}"
  exit 1
fi
