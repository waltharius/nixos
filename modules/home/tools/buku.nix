# Buku bookmark manager with Syncthing synchronization
# Safe sync strategy: export/import workflow to prevent database corruption
# Includes bukuserver web GUI on localhost:5001
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Custom buku with server support and tests disabled to avoid build issues
  bukuWithServer = pkgs.buku.override { withServer = true; };
  
  # Override to skip problematic server tests that require lxml
  bukuServer = bukuWithServer.overridePythonAttrs (old: {
    preCheck = ''
      # Skip all server-related tests to avoid lxml dependency issues
      rm -f tests/test_server.py tests/test_views.py
    '';
    
    # Don't run pytest on these tests
    pytestFlagsArray = old.pytestFlagsArray or [] ++ [
      "--ignore=tests/test_server.py"
      "--ignore=tests/test_views.py"
    ];
  });
in
{
  # Buku with server support + helper scripts
  home.packages = with pkgs; [
    bukuServer        # Buku with web GUI
    bukubrow          # Browser extension host

    # Helper script: Export bookmarks to Syncthing folder
    (writeShellScriptBin "buku-export" ''
      #!/usr/bin/env bash
      # Export buku bookmarks to Syncthing folder
      set -euo pipefail

      SYNC_DIR="$HOME/syncthing/buku"
      JSON_FILE="$SYNC_DIR/bookmarks-$(hostname).json"
      MARKDOWN_FILE="$SYNC_DIR/bookmarks-$(hostname).md"
      HTML_FILE="$SYNC_DIR/bookmarks-$(hostname).html"

      mkdir -p "$SYNC_DIR"

      echo "Exporting bookmarks from $(hostname)..."

      # Export to multiple formats for reliability
      # JSON format (buku's native format)
      ${bukuServer}/bin/buku --export "$JSON_FILE" --format 4
      
      # Also export as Markdown (human readable)
      ${bukuServer}/bin/buku --export "$MARKDOWN_FILE" --format 3
      
      # HTML format (browser import compatible)
      ${bukuServer}/bin/buku --export "$HTML_FILE" --format 2

      echo "✓ Exported to $SYNC_DIR"
      echo "  - JSON: bookmarks-$(hostname).json"
      echo "  - Markdown: bookmarks-$(hostname).md" 
      echo "  - HTML: bookmarks-$(hostname).html"
    '')

    # Helper script: Import bookmarks from another machine
    (writeShellScriptBin "buku-import" ''
      #!/usr/bin/env bash
      # Import bookmarks from another machine
      set -euo pipefail

      SYNC_DIR="$HOME/syncthing/buku"

      if [ $# -eq 0 ]; then
        echo "Usage: buku-import <hostname>"
        echo ""
        echo "Available exports:"
        for file in "$SYNC_DIR"/bookmarks-*.json; do
          if [ -f "$file" ]; then
            basename "$file" | sed 's/bookmarks-//;s/.json//'
          fi
        done
        exit 1
      fi

      SOURCE_HOST="$1"
      JSON_FILE="$SYNC_DIR/bookmarks-$SOURCE_HOST.json"
      HTML_FILE="$SYNC_DIR/bookmarks-$SOURCE_HOST.html"

      # Try JSON first, fall back to HTML if JSON fails
      if [ -f "$JSON_FILE" ]; then
        echo "Importing bookmarks from $SOURCE_HOST (JSON format)..."
        ${bukuServer}/bin/buku --import "$JSON_FILE" --format 4 || {
          echo "JSON import failed, trying HTML format..."
          if [ -f "$HTML_FILE" ]; then
            ${bukuServer}/bin/buku --import "$HTML_FILE"
          else
            echo "Error: No valid export found for $SOURCE_HOST"
            exit 1
          fi
        }
      elif [ -f "$HTML_FILE" ]; then
        echo "Importing bookmarks from $SOURCE_HOST (HTML format)..."
        ${bukuServer}/bin/buku --import "$HTML_FILE"
      else
        echo "Error: No export found for $SOURCE_HOST"
        exit 1
      fi

      echo "✓ Import complete"
    '')

    # Helper script: Merge all exported bookmarks from Syncthing
    (writeShellScriptBin "buku-merge" ''
      #!/usr/bin/env bash
      # Merge all exported bookmarks from Syncthing
      set -euo pipefail

      SYNC_DIR="$HOME/syncthing/buku"
      CURRENT_HOST=$(hostname)

      echo "Merging bookmarks from all machines..."

      for json_file in "$SYNC_DIR"/bookmarks-*.json; do
        if [ -f "$json_file" ]; then
          source_host=$(basename "$json_file" | sed 's/bookmarks-//;s/.json//')

          if [ "$source_host" != "$CURRENT_HOST" ]; then
            echo "  Importing from $source_host..."
            ${bukuServer}/bin/buku --import "$json_file" --format 4 --tacit || {
              # Fall back to HTML if JSON fails
              html_file="$SYNC_DIR/bookmarks-$source_host.html"
              if [ -f "$html_file" ]; then
                echo "    (using HTML format)"
                ${bukuServer}/bin/buku --import "$html_file" --tacit
              fi
            }
          fi
        fi
      done

      echo "✓ Merge complete"
      echo "Tip: Run 'buku-export' to share your updated bookmarks"
    '')
  ];

  # Create buku sync directory structure (updated to syncthing)
  home.file.".local/share/buku/.keep".text = "";
  home.file."syncthing/buku/.keep".text = "";

  # Bukuserver systemd service - Web GUI on localhost:5001
  systemd.user.services.bukuserver = {
    Unit = {
      Description = "Buku bookmark manager web server";
      Documentation = "https://github.com/jarun/buku";
      After = ["network-online.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${bukuServer}/bin/bukuserver run --host 127.0.0.1 --port 5001";
      Restart = "on-failure";
      RestartSec = "10s";

      # Security hardening
      PrivateTmp = true;
      NoNewPrivileges = true;

      # Environment variables for Flask
      Environment = [
        "FLASK_ENV=production"
        "BUKUSERVER_OPEN_IN_NEW_TAB=1"
      ];
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };

  # Automatic export via systemd timer
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
      WantedBy = ["timers.target"];
    };
  };
}
