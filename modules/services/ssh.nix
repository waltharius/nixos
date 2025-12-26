# SSH client configuration with encrypted hosts file
# SSH keys are managed separately through sops-nix secrets
{
  config,
  lib,
  pkgs,
  ...
}: {
  # SOPS configuration for SSH secrets
  sops.secrets = {
    # Encrypted SSH config with all your hosts
    ssh_config = {
      sopsFile = ../../secrets/ssh.yaml;
      path = "${config.home.homeDirectory}/.ssh/config.d/hosts";
      mode = "0600";
    };

    # SSH private keys (one secret per key)
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

  # Create SSH sockets directory for connection multiplexing
  home.file.".ssh/sockets/.keep".text = "";
  home.file.".ssh/config.d/.keep".text = "";

  # SSH program configuration
  programs.ssh = {
    enable = true;

    # FIXED: Set default values explicitly instead of relying on future defaults
    controlMaster = "auto";
    controlPath = "~/.ssh/sockets/%r@%h-%p";
    controlPersist = "10m";
    serverAliveInterval = 60;
    forwardAgent = false;
    compression = false;

    matchBlocks = {
      # Global defaults for all hosts
      "*" = {
        # Include encrypted hosts configuration
        extraOptions = {
          Include = "~/.ssh/config.d/hosts";
        };
      };

      # GitHub-specific configuration
      "github.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519_github";
      };

      "gitlab.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519_gitlab";
      };

      # Local network (Tabby)
      "192.168.50.*" = {
        identityFile = "~/.ssh/id_ed25519_tabby";
      };
    };
  };
}
