# Track-Package: Version Change Detector for NixOS Generations
#
# PURPOSE:
#   Tracks when a specific program's version changed across all NixOS generations.
#   This helps identify which system rebuild introduced a new version of a package,
#   making it easier to debug regressions by pinpointing when changes occurred.
#
# HOW IT WORKS:
#   1. Iterates through all /nix/var/nix/profiles/system-*-link generations
#   2. For each generation, queries the Nix store closure (all dependencies)
#   3. Searches for the specified program in the closure using pattern matching
#   4. Extracts version from the store path (e.g., /nix/store/xxx-firefox-120.0.1)
#   5. Only displays generations where the version actually changed (filters duplicates)
#   6. Shows generation number, date, version change, and store path
#   7. If git commit hashes are embedded in generations, displays them too
#
# OPTIMIZATION:
#   - First checks /sw/bin/<program> directly (fast path)
#   - Only scans full closure if program not found in bin (slow path)
#   - Skips generations where version didn't change
#
# USAGE:
#   track-package firefox     # Track Firefox version changes
#   track-package emacs       # Track Emacs version changes
#   track-package linux       # Track kernel version changes
#
# OUTPUT EXAMPLE:
#   Generation:     #115
#   Date:           2025-12-26 14:30:22
#   Version:        120.0.1 -> 121.0.0
#   Git commit:     abc123def456
#   Store path:     /nix/store/...-firefox-121.0.0
#
# RISK ASSESSMENT:
#   - Read-only operations only (safe)
#   - No system modifications
#   - May be slow on systems with many generations (50+)
#
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "track-package";

  runtimeInputs = with pkgs; [
    nix # For nix-store commands
    coreutils # For basename, readlink, stat
    gnugrep # For grep pattern matching
    gawk # For text processing
  ];

  text = ''
    PROGRAM="''${1:-}"

    if [ -z "$PROGRAM" ]; then
        echo "Usage: track-package <program-name>"
        echo "Example: track-package firefox"
        exit 1
    fi

    echo "Tracking '$PROGRAM' across all generations..."
    echo ""

    prev_version=""
    total_gens=0

    for gen_link in /nix/var/nix/profiles/system-*-link; do
        [ -L "$gen_link" ] || continue

        # Count total generations
        total_gens=$((total_gens + 1))

        gen_num=$(basename "$gen_link" | grep -oP 'system-\K\d+(?=-link)')
        gen_date=$(stat -c "%y" "$gen_link" 2>/dev/null | cut -d'.' -f1)

        git_rev=""
        if [ -f "$gen_link/etc/nixos-git-revision" ]; then
            git_rev=$(cat "$gen_link/etc/nixos-git-revision" 2>/dev/null)
        fi

        # Fast path: check sw/bin first
        program_path=""
        if [ -x "$gen_link/sw/bin/$PROGRAM" ]; then
            program_path=$(readlink -f "$gen_link/sw/bin/$PROGRAM")
        fi

        # Slow path: search full closure
        if [ -z "$program_path" ]; then
            program_path=$(nix-store -qR "$gen_link" 2>/dev/null | \
                          grep -E "/$PROGRAM-[0-9]" | head -1 || echo "")
        fi

        if [ -n "$program_path" ]; then
            version=$(basename "$program_path" | sed "s/^$PROGRAM-//")

            # Only show version changes
            if [ "$version" != "$prev_version" ]; then
                if [ -n "$prev_version" ]; then
                    echo "=================================================="
                fi

                echo "Generation:     #$gen_num"
                echo "Date:           $gen_date"
                if [ -n "$prev_version" ]; then
                    echo "Version change: $prev_version -> $version"
                else
                    echo "Version:        $version"
                fi
                [ -n "$git_rev" ] && echo "Git commit:     ''${git_rev:0:12}"
                echo "Store path:     $program_path"
                echo ""

                prev_version="$version"
            fi
        fi
    done

    if [ -z "$prev_version" ]; then
        echo "[X] Package '$PROGRAM' not found in any generation"
        exit 1
    else
        echo "[OK] Found $PROGRAM in $total_gens total generations"
    fi
  '';

  meta = with pkgs.lib; {
    description = "Track package version changes across NixOS generations";
    license = licenses.mit;
  };
}
