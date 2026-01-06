#!/usr/bin/env bash
# Simple package tracker - uses nixos-rebuild for proper generation order
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

# Use nixos-rebuild to get generations in REVERSE chronological order (newest first)
nixos-rebuild list-generations | tac | while read -r gen_num date time _config_id _kernel _rest; do
  # Skip header line
  if [[ "$gen_num" == "Generation" ]]; then
    continue
  fi
  
  # Search for package in this generation
  pkg_path=$(nix-store -qR "/nix/var/nix/profiles/system-${gen_num}-link" 2>/dev/null | \
    grep -E "[-/]$PACKAGE-[0-9]" | \
    grep -v "\\.drv$" | \
    head -1 || echo "")
  
  if [ -n "$pkg_path" ]; then
    found=true
    version=$(basename "$pkg_path" | sed -E "s/^$PACKAGE-//")
    
    # Only show if version changed or first occurrence
    if [ "$version" != "$prev_version" ]; then
      if [ -z "$prev_version" ]; then
        echo "Gen #$gen_num ($date $time): $version [ADDED]"
      else
        echo "Gen #$gen_num ($date $time): $version [CHANGED from $prev_version]"
      fi
      
      prev_version="$version"
    fi
  elif [ -n "$prev_version" ]; then
    # Package was removed
    echo "Gen #$gen_num ($date $time): [REMOVED]"
    prev_version=""
  fi
done

if [ "$found" = false ]; then
  echo "Package '$PACKAGE' not found in any generation"
  exit 1
fi

echo ""
echo "Done!"
