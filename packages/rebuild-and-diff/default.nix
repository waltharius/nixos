{pkgs, ...}:
pkgs.writeShellApplication {
  name = "rebuild-and-diff";

  # Dependencies
  runtimeInputs = with pkgs; [
    nvd
    nixos-rebuild
    coreutils
  ];

  text = ''
    set -e

    # Get the current generation and store in OLD_GEN
    OLD_GEN=$(readlink /run/current-system)

    # Build the stuff
    echo "Building new stuff for '$HOSTNAME'..."
    sudo nixos-rebuild switch --flake ~/nixos#"$HOSTNAME" "$@"

    # Get new generation after rebuild
    NEW_GEN=$(readlink /run/current-system)

    # Show what changed
    echo ""
    echo "=== System Changes ==="
    nvd diff "$OLD_GEN" "$NEW_GEN"

    # Show generation information
    echo ""
    echo "=== Generation Info ==="

    # Extract generation number from profile link
    current=$(readlink /nix/var/nix/profiles/system |grep -oP 'system-\K\d+(?=-link)' || echo "unknown")

    # Get human-readable size with proper format from nix path-info -Sh with awk
    size=$(nix path-info -Sh /run/current-system 2>/dev/null |awk '{print $2,$3}' || echo "N/A")
    echo "Hostname: $HOSTNAME"
    echo "Current generation: $current"
    echo "System closure size: $size"
  '';

  meta = with pkgs.lib; {
    description = "Rebuild NixOS for current hostname and show diff with nvd";
    license = licenses.mit;
  };
}
