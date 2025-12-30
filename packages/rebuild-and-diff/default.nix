{pkgs, ...}:
pkgs.writeShellApplication {
  name = "rebuild-and-diff";

  # Dependencies
  runtimeInputs = with pkgs; [
    nvd
    nixos-rebuild
  ];

  text = ''
    set -e

    # Get the current generation and store in OLD_GEN
    OLD_GEN=$(readlink /run/current-system)

    # Build the stuff
    echo "Building new stuff for '$HOSTNAME'..."
    sudo nixos-rebuild switch --flake ~/nixos#"$HOSTNAME" "$@"

    # Show what changed
    echo ""
    echo "=== System Changes ==="
    nvd diff "$OLD_GEN" /run/current-system

    # Show generation information
    echo ""
    echo "=== Generation Info ==="
    current=$(readlink /run/current-system |grep -oP '\d+' || echo "unknown")
    size=$(nix path-info -Sh /run/current-system 2>/dev/null |awk '{print $2}' || echo "N/A")
    echo "Hostname: $HOSTNAME"
    echo "Current generation: $current"
    echo "System closure size: $size"
  '';

  meta = with pkgs.lib; {
    description = "Rebuild NixOS for current hostname and show diff with nvd";
    license = licenses.mit;
  };
}
