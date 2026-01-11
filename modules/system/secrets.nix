# Universal SOPS-nix secrets management module
# Works on both laptops and servers
# Handles age key generation and secret decryption
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.services.secrets;
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
    # Import sops-nix module from flake inputs
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # Global sops configuration
    sops = {
      # Default format for all secrets
      defaultSopsFormat = "yaml";

      # Age key file location (per-host)
      age.keyFile = "/var/lib/sops-nix/key.txt";

      # Generate age key on first boot if it doesn't exist
      age.generateKey = true;

      # Atuin credentials (if enabled)
      secrets = mkIf cfg.enableAtuin {
        atuin-password = {
          sopsFile = ../../secrets/atuin.yaml;
          key = "atuin_password";
          mode = "0400";
          owner = "root";
          group = "root";
        };

        atuin-key = {
          sopsFile = ../../secrets/atuin.yaml;
          key = "atuin_key";
          mode = "0400";
          owner = "root";
          group = "root";
        };
      };
    };

    # Ensure sops directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/sops-nix 0755 root root -"
    ];

    # Install sops and age for manual secret management
    environment.systemPackages = with pkgs; [
      sops
      age
    ];
  };
}
