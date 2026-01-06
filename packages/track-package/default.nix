{pkgs, ...}:
pkgs.writeShellApplication {
  name = "track-package";

  runtimeInputs = with pkgs; [
    nix
    coreutils
    gnugrep
    gawk
    findutils
  ];

  text = ''
    PROGRAM="''${1:-}"
    PROFILE_TYPE="''${2:-both}"

    if [ -z "$PROGRAM" ]; then
        echo "Usage: track-package <program-name> [system|home|both]"
        echo ""
        echo "Examples:"
        echo "  track-package firefox          # Search both profiles"
        echo "  track-package firefox system   # Only system packages"
        echo "  track-package emacs home       # Only home-manager packages"
        exit 1
    fi

    search_profile() {
        local profile_pattern="$1"
        local profile_name="$2"

        echo "Searching in $profile_name generations..."
        echo ""

        local prev_version=""
        local total_gens=0
        local found_any=false

        # Use find with sort for consistent ordering
        while IFS= read -r gen_link; do
            [ -L "$gen_link" ] || continue

            total_gens=$((total_gens + 1))

            local gen_num
            gen_num=$(basename "$gen_link" | grep -oP '\d+(?=-link)')

            local gen_date
            gen_date=$(stat -c "%y" "$gen_link" 2>/dev/null | cut -d'.' -f1)

            local git_rev=""
            if [ -f "$gen_link/etc/nixos-git-revision" ]; then
                git_rev=$(cat "$gen_link/etc/nixos-git-revision" 2>/dev/null)
            fi

            # Search in closure for package
            local program_path=""
            program_path=$(nix-store -qR "$gen_link" 2>/dev/null | \
                          grep -E "[-/]$PROGRAM-[0-9]" | \
                          grep -v "\.drv$" | \
                          head -1 || echo "")

            if [ -n "$program_path" ]; then
                found_any=true

                # Extract version: get package name from store path
                local pkg_name
                pkg_name=$(basename "$program_path")

                # Remove program name prefix to get version
                local version
                version=$(echo "$pkg_name" | sed -E "s/^$PROGRAM-//")

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
        done < <(find "$(dirname "$profile_pattern")" -name "$(basename "$profile_pattern")" -type l 2>/dev/null | sort -V)

        if [ "$found_any" = true ]; then
            echo "[OK] Found $PROGRAM in $total_gens $profile_name generations"
            echo ""
            return 0
        else
            echo "[X] Package '$PROGRAM' not found in $profile_name"
            echo ""
            return 1
        fi
    }

    found_anywhere=false

    if [ "$PROFILE_TYPE" = "system" ] || [ "$PROFILE_TYPE" = "both" ]; then
        echo "=== SYSTEM PACKAGES ==="
        if search_profile "/nix/var/nix/profiles/system-*-link" "system"; then
            found_anywhere=true
        fi
    fi

    if [ "$PROFILE_TYPE" = "home" ] || [ "$PROFILE_TYPE" = "both" ]; then
        echo "=== HOME-MANAGER PACKAGES ==="
        home_profile="$HOME/.local/state/nix/profiles/home-manager-*-link"
        if search_profile "$home_profile" "home-manager"; then
            found_anywhere=true
        fi
    fi

    if [ "$found_anywhere" = false ]; then
        echo "Package '$PROGRAM' not found in any searched profile"
        exit 1
    fi
  '';

  meta = with pkgs.lib; {
    description = "Track package version changes across NixOS generations";
    license = licenses.mit;
  };
}
