# parts/dev.nix
#
# Local development tooling. There is no remote CI: every check runs on the
# admin workstation.
#
#   nix develop      - shell with colmena, sops, age, ssh-to-age; entering it
#                      installs the git pre-commit hooks
#   nix fmt          - format all Nix files with alejandra
#   nix flake check  - evaluate every host and run the checks in parts/
#
# Pre-commit hooks run only on staged files. Only the formatter is enabled
# for now; statix and deadnix are planned once the existing code is cleaned
# up, otherwise every commit touching an old file would be blocked.
{inputs, ...}: {
  imports = [inputs.git-hooks.flakeModule];

  perSystem = {
    config,
    pkgs,
    system,
    ...
  }: {
    formatter = pkgs.alejandra;

    pre-commit = {
      # Do not run the hooks over the whole repository inside
      # `nix flake check`; they only guard new commits.
      check.enable = false;
      settings.hooks.alejandra.enable = true;
    };

    devShells.default = pkgs.mkShell {
      packages = [
        inputs.colmena.packages.${system}.colmena
        pkgs.sops
        pkgs.age
        pkgs.ssh-to-age
      ];
      shellHook = config.pre-commit.installationScript;
    };
  };
}
