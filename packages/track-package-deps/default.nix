# Track-Package-Deps: Dependency Inspector for Debugging Broken Packages
#
# PURPOSE:
#   When a program breaks after a rebuild, the issue is often NOT the program itself
#   but one of its dependencies. This tool shows all runtime dependencies and their
#   versions for a specific package in a specific generation, helping identify
#   which dependency changed and might have caused the breakage.
#
# HOW IT WORKS:
#   1. Takes a program name and optional generation number as input
#   2. Locates the program's store path in the specified generation
#   3. Uses 'nix-store -qR' to query RUNTIME dependencies (closure)
#   4. Displays three views of dependency information:
#      a) Flat list of all runtime dependencies (packages this program needs)
#      b) Tree view showing dependency hierarchy (what depends on what)
#      c) Size information for the package and its full closure
#   5. This data can be compared between two generations to find what changed
#
# KEY CONCEPT - RUNTIME DEPENDENCIES:
#   NixOS builds are deterministic - a package depends on specific store paths.
#   If libfoo-1.2.3 breaks but libfoo-1.2.2 worked, you need to know which
#   generation had which version. This tool shows the exact dependency tree.
#
# USAGE:
#   track-package-deps emacs              # Check current generation
#   track-package-deps emacs 115          # Check generation 115
#
#   # Compare two generations to find what changed:
#   track-package-deps emacs 115 > gen115-deps.txt
#   track-package-deps emacs 116 > gen116-deps.txt
#   diff gen115-deps.txt gen116-deps.txt  # See dependency differences
#
# OUTPUT EXAMPLE:
#   Package: /nix/store/xyz-emacs-29.1
#
#   === Runtime Dependencies ===
#     - glibc-2.38-27
#     - ncurses-6.4-2
#     - gtk3-3.24.38
#     ...
#
#   === Dependency Tree (top 10 levels) ===
#   /nix/store/xyz-emacs-29.1
#   ├── glibc-2.38-27
#   │   └── linux-headers-6.5
#   ├── ncurses-6.4-2
#   ...
#
#   === Size Information ===
#   Package size: 234.5 MiB
#   Total closure size: 1.2 GiB
#
# USE CASE SCENARIO:
#   1. Program X stopped working after rebuild
#   2. You bisect and find it broke at generation 116
#   3. Run: track-package-deps program-x 115 > working.txt
#   4. Run: track-package-deps program-x 116 > broken.txt
#   5. Run: diff working.txt broken.txt
#   6. You see: libfoo-1.2.2 → libfoo-1.2.3 (suspect found!)
#   7. Search NixOS issues/PRs for libfoo 1.2.3 to find known breakage
#
# RISK ASSESSMENT:
#   - Read-only operations (safe)
#   - No system modifications
#   - Slow for packages with large closures (200+ dependencies)
#
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "track-package-deps";

  runtimeInputs = with pkgs; [
    nix # For nix-store and nix path-info
    coreutils # For basename, sort
    gnugrep # For pattern matching
    gawk # For parsing nix path-info output
  ];

  text = ''
    PROGRAM="''${1:-}"

    if [ -z "$PROGRAM" ]; then
        echo "Usage: track-package-deps <program-name> [generation-number]"
        echo "Example: track-package-deps emacs 42"
        exit 1
    fi

    GEN_NUM="''${2:-}"

    if [ -z "$GEN_NUM" ]; then
        GEN_LINK="/run/current-system"
    else
        GEN_LINK="/nix/var/nix/profiles/system-$GEN_NUM-link"
        if [ ! -L "$GEN_LINK" ]; then
            echo "Error: Generation $GEN_NUM does not exist"
            exit 1
        fi
    fi

    echo "Finding $PROGRAM in generation..."

    # Locate the program's store path
    PROGRAM_PATH=$(nix-store -qR "$GEN_LINK" 2>/dev/null | \
                   grep -E "/$PROGRAM-[0-9]" | head -1)

    if [ -z "$PROGRAM_PATH" ]; then
        echo "Package $PROGRAM not found in generation"
        exit 1
    fi

    echo "Package: $PROGRAM_PATH"
    echo ""

    # Show all runtime dependencies
    echo "=== Runtime Dependencies ==="
    nix-store -qR "$PROGRAM_PATH" | \
        grep -v "^$PROGRAM_PATH$" | \
        while read -r dep; do
            echo "  - $(basename "$dep")"
        done | sort -u

    echo ""
    echo "=== Dependency Tree (top 50 levels) ==="
    nix-store -q --tree "$PROGRAM_PATH" | head -50

    echo ""
    echo "=== Size Information ==="
    echo "Package size: $(nix path-info -Sh "$PROGRAM_PATH" | awk '{print $2, $3}')"
    echo "Total closure size: $(nix path-info -Sh -r "$PROGRAM_PATH" | tail -1 | awk '{print $2, $3}')"
  '';

  meta = with pkgs.lib; {
    description = "Show package dependencies for debugging broken packages";
    license = licenses.mit;
  };
}
