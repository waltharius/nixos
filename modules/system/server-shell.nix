# modules/system/shell-server.nix
# System-wide shell configuration for servers (atuin, starship, bash)
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    atuin
    starship
    eza
    zoxide
    ripgrep
    fd
    bat
  ];

  # Create /etc/bashrc that gets sourced for all interactive shells
  environment.etc."bashrc".text = ''
    # If not running interactively, don't do anything
    [[ $- != *i* ]] && return

    # Initialize Starship prompt
    if command -v starship &> /dev/null; then
      export STARSHIP_CONFIG="/etc/starship.toml"
      eval "$(${pkgs.starship}/bin/starship init bash)"
    fi

    # Initialize Atuin (shell history) - WITH up arrow support
    if command -v atuin &> /dev/null; then
      export ATUIN_CONFIG_DIR="/etc/atuin"
      eval "$(${pkgs.atuin}/bin/atuin init bash)"
    fi

    # Initialize Zoxide (smart cd)
    if command -v zoxide &> /dev/null; then
      eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
    fi

    # Better history settings
    export HISTSIZE=100000
    export HISTFILESIZE=100000
    export HISTCONTROL=ignoredups:erasedups
    shopt -s histappend

    # Set vim as default editor
    export EDITOR=vim
    export VISUAL=vim
  '';

  programs.bash = {
    enableCompletion = true;

    shellAliases = {
      ls = "eza --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      ll = "eza -alF --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      la = "eza -a --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      lt = "eza --tree --hyperlink --group-directories-first --color=auto --icons --git";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline --graph --decorate";
      gd = "git diff";
      ".." = "cd ..";
      "..." = "cd ../..";
      cat = "bat";
      grep = "grep --color=auto";
    };

    # Make sure /etc/bashrc is sourced
    interactiveShellInit = ''
      # Source system bashrc if not already sourced
      if [ -f /etc/bashrc ] && [ -z "$BASHRC_SOURCED" ]; then
        export BASHRC_SOURCED=1
        source /etc/bashrc
      fi
    '';
  };

  # Configure Starship system-wide
  environment.etc."starship.toml".text = ''
    add_newline = false

    [character]
    success_symbol = "[➜](bold green)"
    error_symbol = "[➜](bold red)"

    [directory]
    truncation_length = 3
    truncate_to_repo = true
    style = "bold cyan"

    [git_branch]
    symbol = " "
    style = "bold purple"

    [nix_shell]
    symbol = " "
    format = "[$symbol$state( ($name))]($style) "
    style = "bold blue"

    [hostname]
    ssh_only = false
    format = "[$hostname](bold red) "
    disabled = false

    [username]
    format = "[$user]($style) "
    disabled = false
    show_always = true

    # Don't show systemd context
    [status]
    disabled = true
  '';

  # Configure Atuin for LOCAL-ONLY mode by default
  environment.etc."atuin/config.toml".text = ''
    # Atuin configuration - LOCAL ONLY by default

    ## Sync disabled by default
    auto_sync = false
    sync_frequency = "0"

    ## Search settings
    search_mode = "fuzzy"
    filter_mode = "host"
    style = "compact"
    show_preview = true

    ## Enable up arrow for atuin search
    # Up arrow will search through history filtered by current directory
    filter_mode_shell_up_key_binding = "directory"

    ## Privacy - never save sensitive commands
    history_filter = [
      "^pass",
      "^password",
      "^secret",
      "^atuin login",
      "^export.*KEY",
      "^export.*SECRET",
      "^export.*TOKEN",
    ]

    ## Local database location
    db_path = "~/.local/share/atuin/history.db"

    ## Enable better search
    inline_height = 20
    show_help = true

    ## Update shell history
    update_snapshots = true
  '';
}
