#!/usr/bin/env bash
# Simple package tracker - no database, just scans generations
# Usage: track-package-simple <package-name>

set -euo pipefail

PACKAGE="${1:-}"

if [ -z "$PACKAGE" ]; then
  echo "Usage: track-package-simple <package-name>"
  echo "Example: track-package-simple firefox"
  exit 1
fi

echo "Tracking '$PACKAGE' across system generations..."
echo ""

prev_version=""
found=false

# Scan system generations
for gen_link in /nix/var/nix/profiles/system-*-link; do
  [ -L "$gen_link" ] || continue
  
  gen_num=$(basename "$gen_link" | grep -oP '\d+(?=-link)')
  
  # Search for package
  package_path=$(nix-store -qR "$gen_link" 2>/dev/null | \
    grep -E "[-/]$PACKAGE-[0-9]" | \
    grep -v "\.drv$" | \
    head -1 || echo "")
  
  if [ -n "$package_path" ]; then
    found=true
    version=$(basename "$package_path" | sed -E "s/^$PACKAGE-//")
    
    # Only show if version changed
    if [ "$version" != "$prev_version" ]; then
      gen_date=$(stat -c "%Y" "$gen_link" 2>/dev/null)
      gen_date=$(date -d "@$gen_date" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
      
      if [ -z "$prev_version" ]; then
        echo "Gen #$gen_num ($gen_date): $version [ADDED]"
      else
        echo "Gen #$gen_num ($gen_date): $version [CHANGED from $prev_version]"
      fi
      
      prev_version="$version"
    fi
  fi
done

if [ "$found" = false ]; then
  echo "Package '$PACKAGE' not found in any generation"
  exit 1
fi

echo ""
echo "Done!"
