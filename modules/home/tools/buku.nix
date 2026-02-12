# modules/home/tools/buku.nix
# Buku bookmark manager with Syncthing synchronization
# Safe sync strategy: export/import workflow to prevent database corruption
# Uses HTML format - the most reliable and portable bookmark format
# Includes bukuserver web GUI on localhost:5001
{
  config,
  pkgs,
  ...
}: let
  # Pin buku to 5.0 until flask-admin compatibility is fixed
  # Issue: buku 5.1 requires flask-admin with 'theme' module
  # but nixpkgs has flask-admin 1.6.1 which doesn't have it
  # Tracking: nixpkgs update from 41e216c → 23d72da broke this
  # First: override buku with server support enabled
  bukuWithServer = pkgs.buku.override {withServer = true;};

  # Then: pin to version 5.0 and skip problematic tests
  bukuServer = bukuWithServer.overridePythonAttrs (old: rec {
    version = "5.0";
    src = pkgs.fetchFromGitHub {
      owner = "jarun";
      repo = "buku";
      rev = "v${version}";
      hash = "sha256-b3j3WLMXl4sXZpIObC+F7RRpo07cwJpAK7lQ7+yIzro=";
    };

    # Skip server tests that have dependency issues
    preCheck = ''
      rm -f tests/test_server.py tests/test_views.py
    '';

    pytestFlagsArray =
      old.pytestFlagsArray or []
      ++ [
        "--ignore=tests/test_server.py"
        "--ignore=tests/test_views.py"
      ];
  });
in {
  # Buku with server support + helper scripts
  home.packages = with pkgs; [
    bukuServer # Buku with web GUI
    bukubrow # Browser extension host

    # Helper script: Export bookmarks to Syncthing folder
    (writeShellScriptBin "buku-export" ''
      #!/usr/bin/env bash
      # Export buku bookmarks to Syncthing folder
      set -euo pipefail

      SYNC_DIR="$HOME/syncthing/buku"
      HTML_FILE="$SYNC_DIR/bookmarks-$(hostname).html"
      MARKDOWN_FILE="$SYNC_DIR/bookmarks-$(hostname).md"
      DB_FILE="$SYNC_DIR/bookmarks-$(hostname).db"

      mkdir -p "$SYNC_DIR"

      echo "Exporting bookmarks from $(hostname)..."

      # Export to HTML (most reliable format for bookmark interchange)
      ${bukuServer}/bin/buku --export "$HTML_FILE"

      # Also export as Markdown (human readable)
      ${bukuServer}/bin/buku --export "$MARKDOWN_FILE"

      # Backup the raw database too
      if [ -f "$HOME/.local/share/buku/bookmarks.db" ]; then
        cp -f "$HOME/.local/share/buku/bookmarks.db" "$DB_FILE"
      fi

      echo "✓ Exported to $SYNC_DIR"
      echo "  - HTML: bookmarks-$(hostname).html ($(wc -l < "$HTML_FILE") lines)"
      echo "  - Markdown: bookmarks-$(hostname).md"
      echo "  - Database: bookmarks-$(hostname).db"
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
        for file in "$SYNC_DIR"/bookmarks-*.html; do
          if [ -f "$file" ]; then
            hostname=$(basename "$file" | sed 's/bookmarks-//;s/.html//')
            count=$(grep -c "<DT>" "$file" || echo "0")
            echo "  $hostname ($count bookmarks)"
          fi
        done
        exit 1
      fi

      SOURCE_HOST="$1"
      HTML_FILE="$SYNC_DIR/bookmarks-$SOURCE_HOST.html"

      if [ ! -f "$HTML_FILE" ]; then
        echo "Error: No export found for $SOURCE_HOST"
        echo "Expected file: $HTML_FILE"
        exit 1
      fi

      # Count bookmarks in the export
      bookmark_count=$(grep -c "<DT>" "$HTML_FILE" || echo "0")
      echo "Found $bookmark_count bookmarks from $SOURCE_HOST"
      echo "Importing..."

      ${bukuServer}/bin/buku --import "$HTML_FILE"

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

      for html_file in "$SYNC_DIR"/bookmarks-*.html; do
        if [ -f "$html_file" ]; then
          source_host=$(basename "$html_file" | sed 's/bookmarks-//;s/.html//')

          if [ "$source_host" != "$CURRENT_HOST" ]; then
            bookmark_count=$(grep -c "<DT>" "$html_file" || echo "0")
            echo "  Importing from $source_host ($bookmark_count bookmarks)..."
            ${bukuServer}/bin/buku --import "$html_file" --tacit
          fi
        fi
      done

      echo "✓ Merge complete"
      echo "Tip: Run 'buku-export' to share your updated bookmarks"
    '')
  ];

  # Create buku sync directory structure
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
