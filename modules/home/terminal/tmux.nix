{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;
    mouse = true;
    escapeTime = 0;
    historyLimit = 1000000;
    baseIndex = 1;
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      catppuccin
      tmux-which-key
      tmux-fzf
      tmux-powerline
      sensible
      sidebar
      sysstat
      battery
      cpu
      copy-toolkit
      harpoon
      jump
      kanagawa
      net-speed
      power-theme
      prefix-highlight
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5'
        '';
      }
    ];
  };
}
