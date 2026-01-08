{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    mouse = true;
    escapeTime = 0;
    historyLimit = 5000000;
    baseIndex = 1;
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      vim-tmux-navigator

      # Keep your tmux-powerline with custom config
      {
        plugin = tmux-powerline;
        extraConfig = ''
          # Disable weather segment to remove "No location defined"
          set -g @tmux_powerline_segments_right "load battery date_time"
          set -g @tmux_powerline_segments_left "session hostname lan_ip wan_ip pwd"

          # Update refresh interval
          set -g @tmux_powerline_refresh_interval 2
        '';
      }

      prefix-highlight

      # Session management
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '60'
        '';
      }
    ];

    extraConfig = ''
      ##### Core Settings #####
      set -ga terminal-overrides ",xterm-256color:Tc"
      set -as terminal-features ",xterm-256color:RGB"
      set -g focus-events on
      set -g status-interval 2
      set -g renumber-windows on
      set -g status-position bottom

      ##### Catppuccin Colors for Powerline #####
      # Override powerline colors with Catppuccin Mocha palette

      # Status bar background and foreground
      set -g status-style bg=#1e1e2e,fg=#cdd6f4

      # Window status styling
      set -g window-status-style bg=#313244,fg=#bac2de
      set -g window-status-current-style bg=#fab387,fg=#1e1e2e,bold
      set -g window-status-activity-style bg=#f38ba8,fg=#1e1e2e

      # Pane borders
      set -g pane-border-style fg=#45475a
      set -g pane-active-border-style fg=#89b4fa

      # Messages
      set -g message-style bg=#313244,fg=#cdd6f4
      set -g message-command-style bg=#313244,fg=#cdd6f4

      ##### Vi Mode #####
      setw -g mode-keys vi
      bind-key -T copy-mode-vi 'v' send -X begin-selection
      bind-key -T copy-mode-vi 'y' send -X copy-pipe-and-cancel
      setw -g mode-style bg=#45475a,fg=#cdd6f4

      ##### Pane Navigation #####
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      ##### Pane Resizing #####
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      ##### Splits #####
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      ##### Clipboard #####
      set -g set-clipboard on
      set -s copy-command 'wl-copy'

      ##### Reload #####
      bind r source-file ~/.config/tmux/tmux.conf \; display "✨ Reloaded!"
    '';
  };

  # Create custom tmux-powerline theme with Catppuccin colors
  home.file.".config/tmux-powerline/themes/catppuccin.sh".text = ''
    # Catppuccin Mocha Theme for tmux-powerline

    # Color definitions
    TMUX_POWERLINE_SEP_LEFT_BOLD=""
    TMUX_POWERLINE_SEP_LEFT_THIN=""
    TMUX_POWERLINE_SEP_RIGHT_BOLD=""
    TMUX_POWERLINE_SEP_RIGHT_THIN=""

    # Catppuccin Mocha colors
    CTP_ROSEWATER="#f5e0dc"
    CTP_FLAMINGO="#f2cdcd"
    CTP_PINK="#f5c2e7"
    CTP_MAUVE="#cba6f7"
    CTP_RED="#f38ba8"
    CTP_MAROON="#eba0ac"
    CTP_PEACH="#fab387"
    CTP_YELLOW="#f9e2af"
    CTP_GREEN="#a6e3a1"
    CTP_TEAL="#94e2d5"
    CTP_SKY="#89dceb"
    CTP_SAPPHIRE="#74c7ec"
    CTP_BLUE="#89b4fa"
    CTP_LAVENDER="#b4befe"
    CTP_TEXT="#cdd6f4"
    CTP_SUBTEXT1="#bac2de"
    CTP_SUBTEXT0="#a6adc8"
    CTP_OVERLAY2="#9399b2"
    CTP_OVERLAY1="#7f849c"
    CTP_OVERLAY0="#6c7086"
    CTP_SURFACE2="#585b70"
    CTP_SURFACE1="#45475a"
    CTP_SURFACE0="#313244"
    CTP_BASE="#1e1e2e"
    CTP_MANTLE="#181825"
    CTP_CRUST="#11111b"

    # Segment colors - customize as needed
    if [ -z "$TMUX_POWERLINE_LEFT_STATUS_SEGMENTS" ]; then
      TMUX_POWERLINE_LEFT_STATUS_SEGMENTS=(
        "tmux_session_info $CTP_BLUE $CTP_BASE"
        "hostname $CTP_MAUVE $CTP_BASE"
        "lan_ip $CTP_GREEN $CTP_BASE"
        "wan_ip $CTP_TEAL $CTP_BASE"
        "pwd $CTP_LAVENDER $CTP_BASE"
      )
    fi

    if [ -z "$TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS" ]; then
      TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS=(
        "load $CTP_YELLOW $CTP_BASE"
        "battery $CTP_GREEN $CTP_BASE"
        "date_day $CTP_SKY $CTP_BASE"
        "date $CTP_PEACH $CTP_BASE"
        "time $CTP_PINK $CTP_BASE"
      )
    fi
  '';

  # Disable weather segment configuration
  home.file.".config/tmux-powerline/segments/weather.sh".text = ''
    # Disabled weather segment
    run_segment() {
      return 0
    }
  '';
}
