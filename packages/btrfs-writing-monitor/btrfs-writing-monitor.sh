#!/usr/bin/env bash
#
# btrfs-writing-monitor — overview and inspection tool for the frequent
# snapper snapshots on the writing subvolumes (documents, notes, syncthing).
#
# Usage:
#   btrfs-writing-monitor status                 Overview of all configs
#   btrfs-writing-monitor list <config> [N]      Last N snapshots (default 30)
#   btrfs-writing-monitor versions <config> <relative/path/to/file>
#                                                 Show only the snapshots where
#                                                 the file's content actually
#                                                 changed (collapses identical
#                                                 consecutive snapshots)
#   btrfs-writing-monitor size                   Disk usage of snapshots
#                                                 (requires the `compsize` tool)
#
# Config -> mountpoint mapping must match modules/system/btrfs.nix
# custom.btrfs.writingSubvolumes on the current host.

set -euo pipefail

declare -A CONFIG_PATHS=(
  [documents]="/home/marcin/Documents"
  [notes]="/home/marcin/notes"
  [syncthing]="/home/marcin/syncthing"
)

usage() {
  grep '^#   btrfs-writing-monitor' "$0" | sed 's/^# //'
  exit 1
}

cmd_status() {
  for cfg in "${!CONFIG_PATHS[@]}"; do
    local path="${CONFIG_PATHS[$cfg]}"
    local snap_dir="${path}/.snapshots"
    local total oldest newest limit

    total=$(snapper -c "$cfg" list --columns number 2>/dev/null | tail -n +3 | grep -c . || echo 0)
    oldest=$(snapper -c "$cfg" list --columns number,date 2>/dev/null | tail -n +3 | head -n1)
    newest=$(snapper -c "$cfg" list --columns number,date 2>/dev/null | tail -n +3 | tail -n1)
    limit=$(snapper -c "$cfg" get-config 2>/dev/null | awk '/NUMBER_LIMIT/ {print $3}')

    echo "== $cfg ($path) =="
    echo "  Snapshots: $total / limit $limit"
    echo "  Oldest:    $oldest"
    echo "  Newest:    $newest"
    echo
  done
}

cmd_list() {
  local cfg="$1"
  local n="${2:-30}"
  [[ -n "${CONFIG_PATHS[$cfg]:-}" ]] || { echo "Unknown config: $cfg" >&2; exit 1; }

  snapper -c "$cfg" list --columns number,date,description | { head -n2; tail -n "$n"; }
}

cmd_versions() {
  local cfg="$1"
  local rel="$2"
  local path="${CONFIG_PATHS[$cfg]:-}"
  [[ -n "$path" ]] || { echo "Unknown config: $cfg" >&2; exit 1; }

  local base="${path}/.snapshots"
  [[ -d "$base" ]] || { echo "No .snapshots directory at $base" >&2; exit 1; }

  local prev_hash=""
  local found=0

  for dir in $(ls -1v "$base" 2>/dev/null); do
    local snap_file="${base}/${dir}/snapshot/${rel}"
    [[ -f "$snap_file" ]] || continue
    local hash
    hash=$(sha256sum "$snap_file" | cut -d' ' -f1)
    if [[ "$hash" != "$prev_hash" ]]; then
      local when
      when=$(snapper -c "$cfg" list --columns number,date | awk -v n="$dir" '$1==n {for(i=2;i<=NF;i++) printf "%s ", $i; print ""}')
      printf "snapshot %-5s %s (sha256 %s)\n" "$dir" "$when" "${hash:0:12}"
      prev_hash="$hash"
      found=1
    fi
  done

  [[ "$found" -eq 1 ]] || echo "File not found in any snapshot under $base: $rel"
}

cmd_size() {
  if ! command -v compsize >/dev/null 2>&1; then
    echo "compsize not found. Run via: nix-shell -p compsize --run '$0 size'" >&2
    exit 1
  fi
  for cfg in "${!CONFIG_PATHS[@]}"; do
    local path="${CONFIG_PATHS[$cfg]}"
    echo "== $cfg ($path/.snapshots) =="
    sudo compsize "${path}/.snapshots"
    echo
  done
}

main() {
  local action="${1:-}"
  shift || true
  case "$action" in
    status)   cmd_status ;;
    list)     [[ $# -ge 1 ]] || usage; cmd_list "$@" ;;
    versions) [[ $# -ge 2 ]] || usage; cmd_versions "$@" ;;
    size)     cmd_size ;;
    *)        usage ;;
  esac
}

main "$@"
