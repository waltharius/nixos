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
      # Add alias for "git alias"
      # (git config alias.pushall '!git push origin main && git push gitlab main')
      # This way I can push to many repositories at once.
      gpa = "git pushall";

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
             # RDP connection to Windows VM
       # Usage: rdp-win11           → connects as marcin (default)
       #        rdp-win11 otheruser → connects as that user
       # Passwords stored in GNOME Keyring: secret-tool store --label="win11 RDP <user>" service rdp-win11 username <user>
      function rdp-win11() {
         local user=''${1:-marcin}
         local pass
         local empty=""
         pass=$(secret-tool lookup service rdp-win11 username "$user" 2>/dev/null)
         if [[ -z "$pass" ]]; then
             echo "No keyring entry found for user '$user'."
             echo "Store it with: secret-tool store --label=\"win11 RDP $user\" service rdp-win11 username $user"
         return 1
         fi
         nohup xfreerdp3 /u:"$user" /d:"$empty" /v:192.168.50.6 \
           /dynamic-resolution /cert:ignore /audio-mode:1 \
           /p:"$pass" &>/dev/null &
         disown
         echo "RDP session started as $user (PID $!)"
       }
    '';
  };
}
