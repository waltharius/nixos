# users/marcin/home/ssh.nix
#
# SSH client configuration with encrypted hosts file.
# SSH keys are managed separately through sops-nix secrets.
#
# Uses the `programs.ssh.settings` API of Home Manager 26.05 (the older
# `matchBlocks` interface is deprecated). Keys are upstream ssh_config
# directive names; booleans are rendered as yes/no.
{config, ...}: {
  sops.secrets = {
    ssh_config = {
      sopsFile = ../../../secrets/ssh.yaml;
      path = "${config.home.homeDirectory}/.ssh/config.d/hosts";
      mode = "0600";
    };
    ssh_key_github = {
      sopsFile = ../../../secrets/ssh.yaml;
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
      mode = "0600";
    };
    ssh_key_gitlab = {
      sopsFile = ../../../secrets/ssh.yaml;
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_gitlab";
      mode = "0600";
    };
    ssh_key_tabby = {
      sopsFile = ../../../secrets/ssh.yaml;
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_tabby";
      mode = "0600";
    };
  };

  home.file = {
    ".ssh/sockets/.keep".text = "";
    ".ssh/config.d/.keep".text = "";
    ".ssh/id_ed25519_github.pub".text = ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInnjB7TwOpPgsSgP1cc47JBcUyNFPm6AKhNxYXVpUoj walth@qazazel-2025
    '';
    ".ssh/id_ed25519_gitlab.pub".text = ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcg9kd0AkQWEQdp6QFaMQVTNXCi8HP3O68U47Zr//l9 Azazel-Fedora42 GitLab
    '';
    ".ssh/id_ed25519_tabby.pub".text = ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025
    '';
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        # Kept inside the "Host *" block (not programs.ssh.includes, which
        # would put Include at the top of the file) so that the precedence
        # of the encrypted hosts file stays exactly as before.
        Include = "~/.ssh/config.d/hosts";
        AddKeysToAgent = "yes";
        ControlMaster = "auto";
        ControlPath = "~/.ssh/sockets/%r@%h-%p";
        ControlPersist = "9m";
        ServerAliveInterval = 59;
        ForwardAgent = false;
        Compression = false;
      };

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

      "192.168.50.*" = {
        IdentityFile = "~/.ssh/id_ed25519_tabby";
      };
    };
  };
}
