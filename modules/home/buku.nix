# Buku bookmark manager with Syncthing synchronization
# Safe sync strategy: export/import workflow to prevent database corruption
{
  config,
  lib,
  pkgs,
  ...
}: {
  # All packages in one definition - helper scripts + main packages
  home.packages = with pkgs; [
    buku
    bukubrow  # Browser extension host
    
    # Helper script: Export bookmarks to Syncthing folder
    (writeShellScriptBin "buku-export" ''
      #!/usr/bin/env bash
      # Export buku bookmarks to Syncthing folder
      set -euo pipefail
      
      SYNC_DIR="$HOME/Sync/buku"
      EXPORT_FILE="$SYNC_DIR/bookmarks-$(hostname).db"
      JSON_FILE="$SYNC_DIR/bookmarks-$(hostname).json"
      
      mkdir -p "$SYNC_DIR"
      
      echo "Exporting bookmarks from $(hostname)..."
      
      # Export to portable formats
      ${buku}/bin/buku --export "$JSON_FILE"
      
      # Also backup the raw database
      cp -f "$HOME/.local/share/buku/bookmarks.db" "$EXPORT_FILE"
      
      echo "✓ Exported to $SYNC_DIR"
      echo "  - JSON: bookmarks-$(hostname).json"
      echo "  - Database: bookmarks-$(hostname).db"
    '')
    
    # Helper script: Import bookmarks from another machine
    (writeShellScriptBin "buku-import" ''
      #!/usr/bin/env bash
      # Import bookmarks from another machine
      set -euo pipefail
      
      SYNC_DIR="$HOME/Sync/buku"
      
      if [ $# -eq 0 ]; then
        echo "Usage: buku-import <hostname>"
        echo ""
        echo "Available exports:"
        ls -1 "$SYNC_DIR"/*.json 2>/dev/null | xargs -n1 basename | sed 's/bookmarks-//;s/.json//' || echo "  (none)"
        exit 1
      fi
      
      SOURCE_HOST="$1"
      JSON_FILE="$SYNC_DIR/bookmarks-$SOURCE_HOST.json"
      
      if [ ! -f "$JSON_FILE" ]; then
        echo "Error: No export found for $SOURCE_HOST"
        exit 1
      fi
      
      echo "Importing bookmarks from $SOURCE_HOST..."
      ${buku}/bin/buku --import "$JSON_FILE"
      echo "✓ Import complete"
    '')
    
    # Helper script: Merge all exported bookmarks from Syncthing
    (writeShellScriptBin "buku-merge" ''
      #!/usr/bin/env bash
      # Merge all exported bookmarks from Syncthing
      set -euo pipefail
      
      SYNC_DIR="$HOME/Sync/buku"
      CURRENT_HOST=$(hostname)
      
      echo "Merging bookmarks from all machines..."
      
      for json_file in "$SYNC_DIR"/bookmarks-*.json; do
        if [ -f "$json_file" ]; then
          source_host=$(basename "$json_file" | sed 's/bookmarks-//;s/.json//')
          
          if [ "$source_host" != "$CURRENT_HOST" ]; then
            echo "  Importing from $source_host..."
            ${buku}/bin/buku --import "$json_file" --tacit
          fi
        fi
      done
      
      echo "✓ Merge complete"
      echo "Tip: Run 'buku-export' to share your updated bookmarks"
    '')
  ];

  # Create buku sync directory structure
  home.file.".local/share/buku/.keep".text = "";
  home.file."Sync/buku/.keep".text = "";

  # Automatic export via systemd timer (optional)
  systemd.user.services.buku-auto-export = {
    Unit = {
      Description = "Auto-export buku bookmarks for Syncthing";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/buku-export";
    };
  };

  systemd.user.timers.buku-auto-export = {
    Unit = {
      Description = "Auto-export buku bookmarks timer";
    };
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
