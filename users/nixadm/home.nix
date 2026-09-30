# Home Manager configuration for nixadm user
# Unified configuration for all servers - same aliases, tools, shell everywhere
{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/home/tools/atuin-sync.nix # Atuin with auto-sync
  ];

  home.username = "nixadm";
  home.homeDirectory = "/home/nixadm";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Atuin is configured by atuin-sync.nix module
  # It will automatically login and sync to atuin.home.lan

  # Bash configuration - identical on all servers
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
      nrs = "sudo nixos-rebuild switch";
      nrt = "sudo nixos-rebuild test";
    };

    # Starship and zoxide are initialised by their Home Manager modules
    # (programs.starship / programs.zoxide, enableBashIntegration = true),
    # which place the init after the interactive-shell guard in ~/.bashrc.
    # Do NOT add them to bashrcExtra: that section runs before the guard,
    # i.e. also for non-interactive `ssh host 'cmd'` sessions, where
    # TERM=dumb makes starship print "[ERROR] - (starship::print)".
  };

  # Starship prompt - server configuration
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
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

      # Always show hostname on servers
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

  # Git configuration for servers
  programs.git = {
    settings = {
      user.name = "nixadm";
      user.email = "nixadm@home.lan";
      init.defaultBranch = "main";
    };
  };
}
