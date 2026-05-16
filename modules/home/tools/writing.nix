# modules/home/tools/writing.nix
#
# Wine environment for running Scrivener 3 (Windows) on NixOS.
#
# Strategy:
#   - Wine version is sourced from pkgs-unstable (passed via specialArgs).
#   - Once Scrivener is configured and working, pin nixpkgs-wine in flake.nix
#     to a specific commit SHA so Wine never changes unexpectedly.
#   - Bottles provides an isolated Wine prefix per application — safer than
#     a shared system Wine prefix.
#   - A backup script is included to snapshot the Bottles prefix after
#     successful Scrivener activation. Restore from backup if Wine breaks.
#
# Setup procedure (after nixos-rebuild switch):
#   1. Launch Bottles, create a new bottle named "Scrivener" (Windows 10 mode)
#   2. Inside the bottle, install via Winetricks: dotnet48, corefonts, vcrun2019
#   3. Install Scrivener Windows installer inside the bottle
#   4. Activate Scrivener (requires internet - one-time only)
#   5. Run: backup-scrivener-bottle
#   6. Pin the Wine version in flake.nix (see comment in flake.nix)
{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages = with pkgs; [
    cabextract
    p7zip
  ];
  # Bottles via Flatpak — official distribution, avoids nixpkgs openldap build issue
  services.flatpak.packages = [
    "com.usebottles.bottles"
  ];

  # Backup helper: snapshot the entire Bottles Scrivener prefix to ~/backups/
  # Run this manually after successful Scrivener activation.
  # Restore with: tar -xzf ~/backups/scrivener-bottles-YYYYMMDD.tar.gz -C /
  home.file.".local/bin/backup-scrivener-bottle" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      BOTTLES_DIR="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles"
      BACKUP_DIR="$HOME/backups"
      BOTTLE_NAME="Scrivener"
      TIMESTAMP=$(date +%Y%m%d_%H%M)
      BACKUP_FILE="$BACKUP_DIR/scrivener-bottles-$TIMESTAMP.tar.gz"

      if [[ ! -d "$BOTTLES_DIR/$BOTTLE_NAME" ]]; then
        echo "ERROR: Bottle '$BOTTLE_NAME' not found at $BOTTLES_DIR/$BOTTLE_NAME"
        echo "Have you created and configured the bottle yet?"
        exit 1
      fi

      mkdir -p "$BACKUP_DIR"
      echo "Backing up Scrivener Bottles prefix..."
      echo "Source: $BOTTLES_DIR/$BOTTLE_NAME"
      echo "Destination: $BACKUP_FILE"

      tar -czf "$BACKUP_FILE" \
        -C "$BOTTLES_DIR" \
        "$BOTTLE_NAME"

      SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
      echo "Done. Backup size: $SIZE"
      echo "Restore with:"
      echo "  tar -xzf $BACKUP_FILE -C $BOTTLES_DIR"
    '';
  };
}
