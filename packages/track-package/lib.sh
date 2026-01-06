#!/usr/bin/env bash
# Library functions for track-package

# Color codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export BOLD='\033[1m'
export DIM='\033[2m'
export NC='\033[0m'

# Escape single quotes for SQL
sql_escape() {
  echo "$1" | sed "s/'/''/g"
}

# Initialize database
init_database() {
  local db_file="$1"
  local schema_file="$2"

  if [ ! -f "$db_file" ]; then
    echo -e "${YELLOW}[Initializing history database...]${NC}"
    sqlite3 "$db_file" <"$schema_file"
    echo -e "${GREEN}[Database initialized: $db_file]${NC}"
  fi
}

# Update GC status for generations
update_gc_status() {
  local db_file="$1"
  local profile_type="$2"

  local existing_gens
  if [ "$profile_type" = "system" ]; then
    existing_gens=$(find /nix/var/nix/profiles -maxdepth 1 -name "system-*-link" -type l 2>/dev/null |
      grep -oP 'system-\K\d+(?=-link)' | sort -n | paste -sd, -)
  else
    existing_gens=$(find "$HOME/.local/state/nix/profiles" -maxdepth 1 -name "home-manager-*-link" -type l 2>/dev/null |
      grep -oP 'home-manager-\K\d+(?=-link)' | sort -n | paste -sd, -)
  fi

  if [ -n "$existing_gens" ]; then
    sqlite3 "$db_file" "UPDATE package_history SET generation_exists = 0 WHERE profile_type = '$profile_type' AND generation_num NOT IN ($existing_gens);"
  fi
}

# Check if generation exists in DB
generation_in_db() {
  local db_file="$1"
  local program="$2"
  local gen_num="$3"
  local profile_type="$4"

  sqlite3 "$db_file" "SELECT COUNT(*) FROM package_history WHERE package_name='$(sql_escape "$program")' AND generation_num=$gen_num AND profile_type='$profile_type';"
}

# Insert package record
insert_package_record() {
  local db_file="$1"
  local program="$2"
  local gen_num="$3"
  local profile_type="$4"
  local version="$5"
  local event="$6"
  local gen_date="$7"
  local git_commit="$8"
  local program_path="$9"
  local scan_timestamp="${10}"

  sqlite3 "$db_file" <<EOSQL
INSERT OR REPLACE INTO package_history 
    (package_name, generation_num, profile_type, version, event, 
     date, git_commit, store_path, generation_exists, scan_timestamp)
VALUES 
    ('$(sql_escape "$program")', $gen_num, '$profile_type', '$(sql_escape "$version")', '$event',
     '$gen_date', $git_commit, '$(sql_escape "$program_path")', 1, '$scan_timestamp');
EOSQL
}

# Get package count from DB
get_package_count() {
  local db_file="$1"
  local program="$2"
  local profile_type="$3"

  sqlite3 "$db_file" "SELECT COUNT(*) FROM package_history WHERE package_name='$(sql_escape "$program")' AND profile_type='$profile_type';"
}

# Get active/GC'd counts
get_gc_stats() {
  local db_file="$1"
  local program="$2"
  local profile_type="$3"
  local stat_type="$4" # 'active' or 'gcd'

  local exists_val
  if [ "$stat_type" = "active" ]; then
    exists_val=1
  else
    exists_val=0
  fi

  sqlite3 "$db_file" "SELECT COUNT(*) FROM package_history WHERE package_name='$(sql_escape "$program")' AND profile_type='$profile_type' AND generation_exists=$exists_val;"
}

# Get event counts
get_event_count() {
  local db_file="$1"
  local program="$2"
  local profile_type="$3"
  local event_type="$4"

  sqlite3 "$db_file" "SELECT COUNT(*) FROM package_history WHERE package_name='$(sql_escape "$program")' AND profile_type='$profile_type' AND event='$event_type';"
}

# Print table header
print_table_header() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  printf " ${BOLD}%-6s${NC} │ ${BOLD}%-19s${NC} │ ${BOLD}%-22s${NC} │ ${BOLD}%-10s${NC} │ ${BOLD}%-14s${NC}\n" \
    "Gen" "Date" "Version" "Event" "Git / Status"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Print table row
print_table_row() {
  local gen="$1"
  local date="$2"
  local version="$3"
  local event="$4"
  local git_commit="$5"
  local exists="$6"

  local event_color status_marker
  case "$event" in
  ADDED)
    event_color="${GREEN}"
    ;;
  REMOVED)
    event_color="${RED}"
    ;;
  UPGRADED | DOWNGRADED)
    event_color="${YELLOW}"
    ;;
  *)
    event_color="${NC}"
    ;;
  esac

  if [ "$exists" = "0" ]; then
    status_marker="${DIM}$git_commit (GC'd)${NC}"
  else
    status_marker="$git_commit"
  fi

  printf " ${BOLD}${BLUE}#%-5s${NC} │ ${CYAN}%-19s${NC} │ ${BOLD}%-22s${NC} │ ${event_color}%-10s${NC} │ %-25s\n" \
    "$gen" "$date" "$version" "$event" "$status_marker"
}
