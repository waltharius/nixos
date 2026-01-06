{pkgs, ...}:
pkgs.writeShellApplication {
  name = "track-package-deps";

  runtimeInputs = with pkgs; [
    nix
    coreutils
    gnugrep
    gawk
  ];

  text = ''
    PROGRAM="''${1:-}"
    GEN_NUM="''${2:-}"
    PROFILE_TYPE="''${3:-system}"

    if [ -z "$PROGRAM" ]; then
        echo "Usage: track-package-deps <program-name> [generation-number] [system|home]"
        echo ""
        echo "Examples:"
        echo "  track-package-deps emacs              # Current system generation"
        echo "  track-package-deps emacs 42           # System generation 42"
        echo "  track-package-deps emacs 42 system    # Explicit system"
        echo "  track-package-deps emacs 15 home      # Home-manager generation 15"
        exit 1
    fi

    # Determine which profile to use
    if [ "$PROFILE_TYPE" = "home" ]; then
        if [ -z "$GEN_NUM" ]; then
            GEN_LINK="$HOME/.local/state/nix/profiles/home-manager"
        else
            GEN_LINK="$HOME/.local/state/nix/profiles/home-manager-$GEN_NUM-link"
        fi
    else
        if [ -z "$GEN_NUM" ]; then
            GEN_LINK="/run/current-system"
        else
            GEN_LINK="/nix/var/nix/profiles/system-$GEN_NUM-link"
        fi
    fi

    if [ ! -L "$GEN_LINK" ]; then
        echo "Error: Generation does not exist: $GEN_LINK"
        exit 1
    fi

    echo "Finding $PROGRAM in generation..."
    echo "Profile: $GEN_LINK"
    echo ""

    # Find the package in closure
    PROGRAM_PATH=$(nix-store -qR "$GEN_LINK" 2>/dev/null | \
                   grep -E "[-/]$PROGRAM-[0-9]" | \
                   grep -v "\.drv$" | \
                   head -1)

    if [ -z "$PROGRAM_PATH" ]; then
        echo "Package $PROGRAM not found in generation"
        exit 1
    fi

    echo "Package: $PROGRAM_PATH"
    echo ""

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
    echo "Package size: $(nix path-info -Sh "$PROGRAM_PATH" 2>/dev/null | awk '{print $2, $3}' || echo 'N/A')"
    echo "Total closure size: $(nix path-info -Sh -r "$PROGRAM_PATH" 2>/dev/null | tail -1 | awk '{print $2, $3}' || echo 'N/A')"
  '';

  meta = with pkgs.lib; {
    description = "Show package dependencies for debugging broken packages";
    license = licenses.mit;
  };
}
