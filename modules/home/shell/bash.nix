{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.bash = {
    enable = true;

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

      # NixOS shortcuts
      nrs = "rebuild-and-diff";
      nrt = "sudo nixos-rebuild test --flake ~/nixos#$(hostname)";
      nrb = "sudo nixos-rebuild boot --flake ~/nixos#$(hostname)";

      # WiFi management (NetworkManager)
      wifi-list = "nmcli device wifi list";
      wifi-connect = "nmcli device wifi connect";
      wifi-status = "nmcli connection show --active";
      wifi-forget = "nmcli connection delete";
      wifi-scan = "nmcli device wifi rescan";

      # Atuin filter modes
      atuin-local = "ATUIN_FILTER_MODE=host atuin search -i";
      atuin-global = "ATUIN_FILTER_MODE=global atuin search -i";
    };

    bashrcExtra = ''

      # Load ble.sh if available
      if [[ -f ${pkgs.blesh}/share/blesh/ble.sh ]]; then
        source ${pkgs.blesh}/share/blesh/ble.sh --noattach
      fi

      eval "$(starship init bash)"

      # Atuin integration
      if command -v atuin &> /dev/null; then
        eval "$(${pkgs.atuin}/bin/atuin init bash)"
      fi

      # Zoxide integration
      if command -v zoxide &> /dev/null; then
        eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
      fi

      # Attach ble.sh after integrations
      [[ ''${BLE_VERSION-} ]] && ble-attach || true

      # Yazi shell wrapper for cd on exit
      if command -v yazi &> /dev/null; then
        function y() {
          local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
          yazi "$@" --cwd-file="$tmp"
          if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
          fi
          rm -f -- "$tmp"
        }
      fi
    '';
  };
}
