# modules/system/secrets.nix
#
# sops-nix on a host: where the host's age key comes from, plus the Atuin
# credentials used by servers.
#
# The key source is chosen per machine in hosts/machines/<host>.nix:
#   sops.keySource = "key-file"      - /var/lib/sops-nix/key.txt, created
#                                      by hand (hosts installed before
#                                      refactor stage 2)
#   sops.keySource = "ssh-host-key"  - derived from the SSH host key
#                                      /etc/ssh/ssh_host_ed25519_key (hosts
#                                      added with `nix run .#new-host`)
# On "key-file" hosts with sshd, sops-nix also tries the ed25519 SSH host key,
# because sops.age.sshKeyPaths defaults to the keys of services.openssh.
#
# Which secret files a host can decrypt is generated from the
# configuration; see secrets/README.md.
{
  config,
  host,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.secrets;
  keyFromFile = host.sops.keySource == "key-file";
in {
  options.services.secrets = {
    enable = mkEnableOption "SOPS-nix secrets management";

    enableAtuin = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Atuin credential secrets";
    };
  };

  config = mkIf cfg.enable {
    # Global sops configuration
    sops = {
      # Age key file of "key-file" hosts. On "ssh-host-key" hosts sops-nix
      # uses only the SSH host key (sops.age.sshKeyPaths default).
      age.keyFile =
        if keyFromFile
        then "/var/lib/sops-nix/key.txt"
        else null;

      # Keys are never generated on the host: the public key must be in the
      # repository before the host can decrypt anything.
      age.generateKey = false;

      # Atuin credentials (if enabled)
      secrets = mkIf cfg.enableAtuin {
        atuin-password = {
          sopsFile = ../../secrets/atuin-password.txt;
          format = "binary";
          mode = "0400";
          owner = "root";
          group = "root";
        };

        atuin-key = {
          sopsFile = ../../secrets/atuin-key.txt;
          format = "binary";
          mode = "0400";
          owner = "root";
          group = "root";
        };
      };
    };

    # Ensure sops directory exists with correct permissions
    systemd.tmpfiles.rules = lib.optional keyFromFile "d /var/lib/sops-nix 0755 root root -";

    # Install sops and age for manual secret management
    environment.systemPackages = with pkgs; [
      sops
      age
    ];
  };
}
