# parts/fleet.nix
#
#   nix run .#fleet  - one entry point for repository and fleet tasks; run
#                      without arguments it lists the tasks to choose from
#                      (scripts/fleet.sh, docs/MONITORING.md for
#                      "monitoring apply")
#
# Ansible is a runtime input of this script only, pinned by flake.lock and
# installed in no group; its collections come from ansible/requirements.yml.
{lib, ...}: {
  perSystem = {pkgs, ...}: {
    apps.fleet = {
      type = "app";
      meta.description = "Repository and fleet tasks: choose from a list or run one directly";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "fleet";
        # nix itself comes from the caller's PATH, as in new-host.
        runtimeInputs = with pkgs; [
          alejandra
          ansible
          coreutils
          curl
          findutils
          git
          gawk
          gnugrep
          gnused
          gum
          jq
          openssh
        ];
        text = builtins.readFile ../scripts/fleet.sh;
      });
    };
  };
}
