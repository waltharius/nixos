# modules/services/ssh.nix
#
# SSH client configuration with encrypted hosts file.
# SSH keys are managed separately through sops-nix secrets.
#
# programs.ssh.matchBlocks remains the correct Home Manager API for
# per-host SSH configuration and is NOT deprecated.
# What was deprecated (HM 26.05) is matchBlocks.*.extraOptions: these
# raw OpenSSH directive strings are replaced by first-class HM options
# where available. "Include" is now a direct attribute on the match block.
{ config, ... }: {
  sops.secrets = {
    ssh_config = {
      sopsFile = ../../secrets/ssh.yaml;
      path = "${config.home.homeDirectory}/.ssh/config.d/hosts";
      mode = "0600";
    };
    ssh_key_github = {
      sopsFile = ../../secrets/ssh.yaml;
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
      mode = "0600";
    };
    ssh_key_gitlab = {
      sopsFile = ../../secrets/ssh.yaml;
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_gitlab";
      mode = "0600";
    };
    ssh_key_tabby = {
      sopsFile = ../../secrets/ssh.yaml;
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

    matchBlocks = {
      # Global defaults applied to every connection.
      # "Include" is now a first-class matchBlocks attribute in HM 26.05,
      # replacing the deprecated extraOptions.Include form.
      "*" = {
        includes = [ "~/.ssh/config.d/hosts" ];
        addKeysToAgent = "yes";
        controlMaster = "auto";
        controlPath = "~/.ssh/sockets/%r@%h-%p";
        controlPersist = "9m";
        serverAliveInterval = 59;
        forwardAgent = false;
        compression = false;
      };

      "github.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519_github";
      };

      "gitlab.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519_gitlab";
      };

      "gitlab.home.lan" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519_gitlab";
      };

      "192.168.50.*" = {
        identityFile = "~/.ssh/id_ed25519_tabby";
      };
    };
  };
}
