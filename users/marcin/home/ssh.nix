# users/marcin/home/ssh.nix
#
# SSH client configuration. The private keys and the encrypted host list
# are decrypted by the system sops-nix (users/marcin/secrets.nix); this file
# adds the public keys, ~/.ssh/config and the layered host lists in
# ~/.ssh/config.d/ (described in ./ssh-config.d-README.md, which is
# installed as ~/.ssh/config.d/README.md, and in docs/SSH.md).
#
# Layers, highest precedence first (ssh uses the first value it finds):
#   local    - yours, never managed or overwritten; temporary/test hosts
#   hosts    - encrypted private list (secrets/users/marcin/admin.yaml)
#   fleet    - generated from hosts/machines/*.nix
#   devices  - generated from hosts/devices/*.nix
# hosts, fleet and devices only exist where marcin has nix-admin.
#
# Uses the `programs.ssh.settings` API of Home Manager 26.05 (the older
# `matchBlocks` interface is deprecated). Keys are upstream ssh_config
# directive names; booleans are rendered as yes/no.
{
  config,
  lib,
  osConfig,
  ...
}: let
  # Same rule as users/marcin/secrets.nix, which decrypts the keys.
  hasGroup = g: builtins.elem g config.fleet.groups;
  gitKeys = hasGroup "emacs" || hasGroup "nix-admin";
  adminKeys = hasGroup "nix-admin";

  layers =
    ["~/.ssh/config.d/local"]
    ++ lib.optionals adminKeys [
      "~/.ssh/config.d/hosts"
      "~/.ssh/config.d/fleet"
      "~/.ssh/config.d/devices"
    ];
in {
  home.file =
    {
      ".ssh/sockets/.keep".text = "";
      ".ssh/config.d/README.md".source = ./ssh-config.d-README.md;
    }
    // lib.optionalAttrs gitKeys {
      ".ssh/id_ed25519_github.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInnjB7TwOpPgsSgP1cc47JBcUyNFPm6AKhNxYXVpUoj walth@qazazel-2025
      '';
      ".ssh/id_ed25519_gitlab.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcg9kd0AkQWEQdp6QFaMQVTNXCi8HP3O68U47Zr//l9 Azazel-Fedora42 GitLab
      '';
    }
    // lib.optionalAttrs adminKeys {
      ".ssh/config.d/fleet".text = osConfig.fleet.ssh.fleetConfig;
      ".ssh/config.d/devices".text = osConfig.fleet.ssh.devicesConfig;
      ".ssh/id_ed25519_tabby.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025
      '';
    };

  # ~/.ssh/config.d/local belongs to you: created once with a short header,
  # never touched again by Home Manager.
  home.activation.sshLocalConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    local_config="$HOME/.ssh/config.d/local"
    if [ ! -e "$local_config" ]; then
      run mkdir -p "$HOME/.ssh/config.d"
      run install -m 0600 /dev/null "$local_config"
      if [ -z "''${DRY_RUN:-}" ]; then
        cat > "$local_config" <<'EOF'
    # ~/.ssh/config.d/local - your own SSH hosts, highest precedence.
    # Not managed by Home Manager: nothing here is ever overwritten.
    # Use it for temporary and test entries; move permanent hosts to
    # hosts/devices/ in the nixos repository. See README.md here.
    EOF
      fi
    fi
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings =
      {
        "*" =
          {
            AddKeysToAgent = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/sockets/%r@%h-%p";
            ControlPersist = "9m";
            ServerAliveInterval = 59;
            ForwardAgent = false;
            Compression = false;
          }
          // {
            # Kept inside the "Host *" block (not programs.ssh.includes, which
            # would put Include at the top of the file) so that the precedence
            # of the included files stays as before. The order of the files
            # is the precedence of the layers; missing files are skipped.
            Include = lib.concatStringsSep " " layers;
          };
      }
      // lib.optionalAttrs gitKeys {
        "github.com" = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519_github";
        };

        "gitlab.com" = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519_gitlab";
        };

        "gitlab.home.lan" = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519_gitlab";
        };
      }
      // lib.optionalAttrs adminKeys {
        "192.168.50.*" = {
          IdentityFile = "~/.ssh/id_ed25519_tabby";
        };
      };
  };
}
