{pkgs, ...}: {
  environment.systemPackages = with pkgs; [atuin];

  programs.bash.interactiveShellInit = ''
    # Atuin - local only, no sync
    if command -v atuin &> /dev/null; then
      # Inicjalizacja bez up-arrow (bezpieczniejsze)
      eval "$(${pkgs.atuin}/bin/atuin init bash --disable-up-arrow)"

      # Bind Ctrl+R do atuin search
      bind -x '"\C-r": __atuin_history'
    fi
  '';

  systemd.tmpfiles.rules = [
    "d /root/.local/share/atuin 0700 root root -"
  ];
}
