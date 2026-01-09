# modules/system/shell-server.nix
# System-wide shell configuration for servers (atuin, starship, bash)
{pkgs, ...}: {
  # Install required packages system-wide
  environment.systemPackages = with pkgs; [
    atuin
    starship
    eza
    zoxide
    ripgrep
    fd
    bat
  ];

  # Configure bash system-wide
  programs.bash = {
    # Enable bash completion
    enableCompletion = true;

    # System-wide aliases for all users
    shellAliases = {
      # Enhanced ls with eza
      ls = "eza --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      ll = "eza -alF --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      la = "eza -a --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      lt = "eza --tree --hyperlink --group-directories-first --color=auto --icons --git";

      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline --graph --decorate";
      gd = "git diff";
      gco = "git checkout";

      # System shortcuts
      ".." = "cd ..";
      "..." = "cd ../..";

      # Useful tools
      cat = "bat";
    };

    # System-wide bash configuration
    interactiveShellInit = ''
      # Initialize Starship prompt
      eval "$(${pkgs.starship}/bin/starship init bash)"

      # Initialize Atuin (shell history)
      eval "$(${pkgs.atuin}/bin/atuin init bash --disable-up-arrow)"

      # Initialize Zoxide (smart cd)
      eval "$(${pkgs.zoxide}/bin/zoxide init bash)"

      # Better history settings
      export HISTSIZE=100000
      export HISTFILESIZE=100000
      export HISTCONTROL=ignoredups:erasedups

      # Append to history, don't overwrite
      shopt -s histappend

      # Set vim as default editor
      export EDITOR=vim
      export VISUAL=vim

      # Color support for ls and grep
      alias grep='grep --color=auto'
      alias fgrep='fgrep --color=auto'
      alias egrep='egrep --color=auto'
    '';
  };

  # Configure Starship system-wide
  environment.etc."starship.toml".text = ''
    # Starship configuration for servers
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
  '';

  # Configure Atuin for LOCAL-ONLY mode by default
  environment.etc."atuin/config.toml".text = ''
    # Atuin configuration - LOCAL ONLY by default

    ## Sync disabled by default (enable manually per server)
    auto_sync = false
    sync_frequency = "0"

    ## Uncomment and configure when ready to sync with your server:
    # sync_address = "https://atuin.home.lan"
    # auto_sync = true
    # sync_frequency = "300"

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
      "^export.*KEY",
      "^export.*SECRET",
      "^export.*TOKEN",
    ]

    ## Local database location
    db_path = "~/.local/share/atuin/history.db"

    ## Enable better search
    inline_height = 20
    show_help = true
  '';

  # Set STARSHIP_CONFIG environment variable
  environment.variables = {
    STARSHIP_CONFIG = "/etc/starship.toml";
    ATUIN_CONFIG_DIR = "/etc/atuin";
  };
}
