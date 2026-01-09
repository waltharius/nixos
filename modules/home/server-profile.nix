{
  config,
  lib,
  pkgs,
  ...
}: {
  # Atuin without daemon (local history only)
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      # No sync on test server
      auto_sync = false;
      
      # Local settings
      filter_mode = "host";
      search_mode = "fuzzy";
      style = "compact";
      show_preview = true;
      filter_mode_shell_up_key_binding = "directory";

      # Privacy - never save sensitive commands
      history_filter = [
        "^pass"
        "^password"
        "^secret"
        "^atuin login"
      ];

      # Disable daemon for servers (no graphical session)
      daemon = {
        enabled = false;
      };
    };
  };

  # Minimal bash setup for servers
  programs.bash = {
    enable = true;

    shellAliases = {
      # Enhanced ls with eza
      ls = "eza --group-directories-first --color=auto --icons";
      ll = "eza -alF --group-directories-first --color=auto --icons";
      la = "eza -a --group-directories-first --color=auto --icons";
      
      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      
      # NixOS shortcuts for remote management
      nrs = "nixos-rebuild switch";
    };

    bashrcExtra = ''
      # Starship prompt (if available)
      if command -v starship &> /dev/null; then
        eval "$(starship init bash)"
      fi

      # Zoxide (smart cd)
      if command -v zoxide &> /dev/null; then
        eval "$(zoxide init bash)"
      fi
    '';
  };

  # Starship prompt - minimal server config
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$character"
      ];
      
      # Show hostname on servers
      hostname = {
        ssh_only = false;
        format = "[@$hostname](bold red):";
      };
      
      # Compact directory display
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };
    };
  };

  # Zoxide - smart directory jumping
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  home.stateVersion = "25.11";
}
