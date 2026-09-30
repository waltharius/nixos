# modules/home/admin/bash.nix
#
# Bash with ble.sh, shared by every admin account.
#
# Order inside ~/.bashrc (Home Manager builds it from programs.bash):
#   bashrcExtra  - runs for EVERY shell, also `ssh host 'cmd'`; keep it free
#                  of prompt and line-editor setup
#   [[ $- == *i* ]] || return   - interactive-shell guard
#   aliases, then initExtra, ordered by lib.mkOrder:
#      100  bash-completion (Home Manager)
#      150  ble.sh, loaded without attaching (this file)
#     1000  atuin (Home Manager, ./atuin.nix)
#     1900  starship (Home Manager, ./starship.nix)
#     2000  zoxide (Home Manager, ./zoxide.nix)
#     3000  ble-attach (this file) - must come after all integrations
#
# starship, atuin and zoxide are initialised only by their Home Manager
# modules. Initialising them again here would run them twice and, if done
# in bashrcExtra, also in non-interactive shells, where TERM=dumb makes
# starship print "[ERROR] - (starship::print)".
{
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

      # Git shortcuts. `gst`, not `gs`: gs is Ghostscript.
      gst = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
    };

    initExtra = lib.mkMerge [
      (lib.mkOrder 150 ''
        # ble.sh: line editor with syntax highlighting and autosuggestions.
        # Loaded detached; ble-attach at the end of .bashrc attaches it after
        # every other integration has set up its hooks.
        if [[ $TERM != dumb ]]; then
          source ${pkgs.blesh}/share/blesh/ble.sh --noattach
        fi
      '')
      (lib.mkOrder 3000 ''
        [[ ''${BLE_VERSION-} ]] && ble-attach || true
      '')
    ];
  };
}
