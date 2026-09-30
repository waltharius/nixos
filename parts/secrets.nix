# parts/secrets.nix
#
# .sops.yaml generated from the fleet (lib/secrets.nix):
#   nix run .#sops-config  - write .sops.yaml and re-encrypt every secret
#                            file for its current audience (needs the admin
#                            key, run it on azazel from the repository root)
#   packages.sops-config   - the generated file, for inspection
#
# Checks (run by `nix flake check`):
#   sops-config     - the committed .sops.yaml equals the generated one
#   sops-recipients - every encrypted file in secrets/ is encrypted for
#                     exactly the keys its rule names
#
# The flake only sees files tracked by git: `git add` a new secret file
# before running `nix run .#sops-config`.
{
  self,
  lib,
  ...
}: let
  secrets = import ../lib/secrets.nix {
    inherit lib;
    inherit (self) inventory nixosConfigurations;
  };

  fail = problems: fix:
    throw ''
      ${lib.concatMapStrings (p: "  - ${p}\n") problems}
      Fix: ${fix}'';
in {
  perSystem = {pkgs, ...}: let
    generated = pkgs.writeText "sops.yaml" secrets.text;
  in {
    packages.sops-config = generated;

    apps.sops-config = {
      type = "app";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "sops-config";
        runtimeInputs = [pkgs.sops pkgs.git pkgs.coreutils pkgs.diffutils];
        text = ''
          root=$(git rev-parse --show-toplevel)
          cd "$root"
          if [ ! -f flake.nix ] || [ ! -d hosts/machines ]; then
            echo "sops-config: run it inside the nixos repository" >&2
            exit 1
          fi

          if cmp -s ${generated} .sops.yaml; then
            echo ".sops.yaml is up to date"
          else
            if [ -f .sops.yaml ]; then
              diff -u .sops.yaml ${generated} || true
            fi
            install -m 0644 ${generated} .sops.yaml
            echo "wrote .sops.yaml"
          fi

          # Re-encrypt the data key of every secret file for the keys its
          # rule names. Files that are already right are left unchanged.
          for file in ${lib.escapeShellArgs secrets.secretFiles}; do
            if [ -f "$file" ]; then
              sops updatekeys --yes "$file"
            fi
          done
        '';
      });
    };

    checks = {
      sops-config =
        if secrets.configProblems == []
        then pkgs.writeText "sops-config-ok" ""
        else fail secrets.configProblems "run `nix run .#sops-config` and commit .sops.yaml together with the re-encrypted files";

      sops-recipients =
        if secrets.recipientProblems == []
        then pkgs.writeText "sops-recipients-ok" ""
        else fail secrets.recipientProblems "run `nix run .#sops-config` (it runs `sops updatekeys` on every secret file)";
    };
  };
}
