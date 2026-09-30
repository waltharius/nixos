# users/marcin/secrets.nix
#
# marcin's SSH keys, decrypted by the system sops-nix with the host key
# (not by Home Manager with a user key: hosts added with `new-host` derive
# their key from the root-only SSH host key, which a user service cannot
# read). Imported by users/marcin/account.nix.
#
# Which keys a host gets depends on marcin's groups on that host
# (hosts/machines/<host>.nix):
#   emacs or nix-admin - git keys (GitHub, GitLab); the Emacs configuration
#                        and the notes live in git repositories
#                        -> secrets/users/marcin/git.yaml
#   nix-admin          - the LAN admin key (tabby) and the private SSH host
#                        list (~/.ssh/config.d/hosts)
#                        -> secrets/users/marcin/admin.yaml
# The two files have different audiences on purpose: sops encrypts a whole
# file for all its recipients, so a writing laptop that can decrypt the git
# keys must not share a file with the key that logs into every server.
{
  config,
  host,
  lib,
  pkgs,
  ...
}: let
  groups = host.users.marcin.groups or [];
  hasGroup = g: builtins.elem g groups;
  gitKeys = hasGroup "emacs" || hasGroup "nix-admin";
  adminKeys = hasGroup "nix-admin";

  user = config.users.users.marcin;
  sshDir = "${user.home}/.ssh";

  secret = sopsFile: key: path: {
    inherit sopsFile key path;
    owner = "marcin";
    inherit (user) group;
    mode = "0600";
  };

  secrets =
    lib.optionalAttrs gitKeys {
      "marcin/ssh_key_github" = secret ../../secrets/users/marcin/git.yaml "ssh_key_github" "${sshDir}/id_ed25519_github";
      "marcin/ssh_key_gitlab" = secret ../../secrets/users/marcin/git.yaml "ssh_key_gitlab" "${sshDir}/id_ed25519_gitlab";
    }
    // lib.optionalAttrs adminKeys {
      "marcin/ssh_key_tabby" = secret ../../secrets/users/marcin/admin.yaml "ssh_key_tabby" "${sshDir}/id_ed25519_tabby";
      "marcin/ssh_config" = secret ../../secrets/users/marcin/admin.yaml "ssh_config" "${sshDir}/config.d/hosts";
    };
in {
  sops.secrets = secrets;

  # sops-nix creates missing parent directories of a secret's path as root.
  # On a fresh host ~/.ssh would then belong to root and Home Manager could
  # not write into it, so create it with the right owner first.
  system.activationScripts = lib.mkIf (secrets != {}) {
    marcin-ssh-dir = lib.stringAfter ["users" "groups"] ''
      ${pkgs.coreutils}/bin/install -d -m 0700 -o marcin -g ${user.group} ${sshDir} ${sshDir}/config.d
    '';
    setupSecrets.deps = ["marcin-ssh-dir"];
  };
}
