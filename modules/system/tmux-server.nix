# Tmux configuration for servers
{...}: {
  programs.tmux = {
    enable = true;

    terminal = "screen-256color";
    historyLimit = 10000;

    extraConfig = ''
      # Enable mouse mode
      set -g mouse on

      # Start windows and panes at 1, not 0
      set -g base-index 1
      setw -g pane-base-index 1

      # Renumber windows when one is closed
      set -g renumber-windows on

      # Better splitting
      bind | split-window -h
      bind - split-window -v

      # Easy config reload
      bind r source-file /etc/tmux.conf \; display "Config reloaded!"

      # Vi mode
      setw -g mode-keys vi

      # Status bar
      set -g status-bg black
      set -g status-fg white
      set -g status-interval 60
      set -g status-left-length 30
      set -g status-left '#[fg=green](#S) #(whoami)'
      set -g status-right '#[fg=yellow]#(cut -d " " -f 1-3 /proc/loadavg)#[default] #[fg=white]%H:%M#[default]'
    '';
  };
}
