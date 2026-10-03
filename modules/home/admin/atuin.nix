# modules/home/admin/atuin.nix
#
# Atuin shell history for every admin account, synced to the self-hosted
# server at atuin.home.lan.
#
# Syncing:
#   - workstations: the Atuin daemon (Home Manager's systemd user service
#     with socket activation) records and syncs in the background.
#   - servers and virtual machines: no user session is guaranteed, so the
#     shell syncs by itself (auto_sync) every 5 minutes.
#
# Logging in: the NixOS services `atuin-auto-login-<user>`
# (modules/system/atuin-login.nix) log nixadm (servers) and marcin
# (workstations) in with the fleet credentials from sops and fail when a
# host uses a different key. Never run `atuin login` by hand.
{host, ...}: let
  onWorkstation = host.class == "workstation";
in {
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;

    daemon.enable = onWorkstation;

    settings = {
      sync_address = "https://atuin.home.lan";

      # With the daemon, syncing is its job; otherwise the shell syncs.
      auto_sync = !onWorkstation;
      sync_frequency = "5m";

      sync.records = true;

      # How often the daemon syncs (seconds); only used on workstations.
      daemon.sync_frequency = 300;

      # Filter by host by default
      filter_mode = "host";

      # Search settings
      search_mode = "fuzzy";
      style = "compact";
      show_preview = true;

      # Smart Up arrow - filter by directory
      filter_mode_shell_up_key_binding = "directory";

      # Privacy - never save sensitive commands
      history_filter = [
        "^pass"
        "^password"
        "^secret"
        "^atuin login"
        "^atuin register"
      ];
    };
  };

  programs.bash.shellAliases = {
    # Search this host's history only / the whole synced history
    atuin-local = "ATUIN_FILTER_MODE=host atuin search -i";
    atuin-global = "ATUIN_FILTER_MODE=global atuin search -i";
  };
}
