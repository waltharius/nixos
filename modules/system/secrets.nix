# SOPS secrets configuration
# This module sets up sops-nix for system-level secrets management
#
# IMPORTANT: This uses SSH host keys for decryption!
# - SSH host key is generated automatically during NixOS installation
# - sops-nix converts it to age format automatically
# - No manual key generation needed!
{
  config,
  lib,
  pkgs,
  ...
}: {
  sops = {
    # Default secrets file (not used, but required by sops-nix)
    defaultSopsFile = ../../secrets/ssh.yaml;

    # CRITICAL: Use SSH host key for decryption instead of separate age key
    # This SSH key is generated automatically during NixOS installation
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

    # Automatically generate age key from SSH key
    age.generateKey = true;

    # Derived age key will be stored here (auto-generated from SSH key)
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # Global secrets (defined per-module, not here)
    # Each module (wifi.nix, sshd.nix) defines its own secrets
    secrets = {};
  };
}
