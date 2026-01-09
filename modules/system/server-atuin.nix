# Atuin shell history with server sync for containers/servers
{
  pkgs,
  lib,
  ...
}: {
  # Install atuin system-wide
  environment.systemPackages = with pkgs; [atuin];

  # Configure atuin system-wide
  environment.etc."atuin/config.toml".text = ''
    # Atuin server sync configuration

    ## Your self-hosted Atuin server
    sync_address = "https://atuin.home.lan"

    ## Auto-sync settings
    auto_sync = true
    sync_frequency = "300"  # Sync every 5 minutes

    ## Search settings
    search_mode = "fuzzy"
    filter_mode = "host"
    style = "compact"
    show_preview = true

    ## Smart Up arrow - filter by directory
    filter_mode_shell_up_key_binding = "directory"

    ## Privacy - never save sensitive commands
    history_filter = [
      "^pass",
      "^password",
      "^secret",
      "^atuin login",
      "^atuin register",
      "^export.*KEY",
      "^export.*SECRET",
      "^export.*TOKEN",
      "^sudo.*password",
    ]

    ## Local database location
    db_path = "~/.local/share/atuin/history.db"

    ## Better search UI
    inline_height = 20
    show_help = true

    ## Update shell history
    update_snapshots = true

    ## Sync records (command history + metadata)
    sync.records = true
  '';

  # Bash integration for atuin
  programs.bash.interactiveShellInit = lib.mkAfter ''
    # Initialize Atuin for shell history
    if command -v atuin &> /dev/null; then
      export ATUIN_CONFIG_DIR="/etc/atuin"
      eval "$(${pkgs.atuin}/bin/atuin init bash)"
    fi
  '';
}
