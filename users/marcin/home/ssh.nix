# users/marcin/home/ssh.nix
#
# SSH client configuration. The private keys and the encrypted host list
# are decrypted by the system sops-nix (users/marcin/secrets.nix); this file
# only adds the public keys and ~/.ssh/config.
#
# Uses the `programs.ssh.settings` API of Home Manager 26.05 (the older
# `matchBlocks` interface is deprecated). Keys are upstream ssh_config
# directive names; booleans are rendered as yes/no.
{
  config,
  lib,
  ...
}: let
  # Same rule as users/marcin/secrets.nix, which decrypts the keys.
  hasGroup = g: builtins.elem g config.fleet.groups;
  gitKeys = hasGroup "emacs" || hasGroup "nix-admin";
  adminKeys = hasGroup "nix-admin";
in {
  home.file =
    {
      ".ssh/sockets/.keep".text = "";
      ".ssh/config.d/.keep".text = "";
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
      ".ssh/id_ed25519_tabby.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025
      '';
    };

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
          // lib.optionalAttrs adminKeys {
            # Kept inside the "Host *" block (not programs.ssh.includes, which
            # would put Include at the top of the file) so that the precedence
            # of the encrypted hosts file stays exactly as before.
            Include = "~/.ssh/config.d/hosts";
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
