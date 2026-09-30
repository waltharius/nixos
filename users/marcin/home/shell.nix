# users/marcin/home/shell.nix
#
# marcin's personal shell additions on top of the admin base
# (modules/home/admin/bash.nix).
{...}: {
  programs.bash = {
    shellAliases = {
      # `git pushall` is a git alias pushing to several remotes:
      # git config alias.pushall '!git push origin main && git push gitlab main'
      gpa = "git pushall";

      # WiFi management (NetworkManager)
      wifi-list = "nmcli device wifi list";
      wifi-connect = "nmcli device wifi connect";
      wifi-status = "nmcli connection show --active";
      wifi-forget = "nmcli connection delete";
      wifi-scan = "nmcli device wifi rescan";
    };

    initExtra = ''
      # RDP connection to Windows VM
      # Usage: rdp-win11           -> connects as marcin (default)
      #        rdp-win11 otheruser -> connects as that user
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
        nohup xfreerdp /u:"$user" /d:"$empty" /v:192.168.50.6 \
          /dynamic-resolution /cert:ignore /audio-mode:1 \
          /p:"$pass" &>/dev/null &
        disown
        echo "RDP session started as $user (PID $!)"
      }
    '';
  };
}
