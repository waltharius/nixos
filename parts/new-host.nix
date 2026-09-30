# parts/new-host.nix
#
#   nix run .#new-host  - register a new machine: inventory entry, host files,
#                         SSH host key, sops audience (scripts/new-host.sh,
#                         docs/NEW-HOST.md)
{lib, ...}: {
  perSystem = {pkgs, ...}: {
    apps.new-host = {
      type = "app";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "new-host";
        # nix itself comes from the caller's PATH, so the script uses the
        # same Nix as the rest of the workflow.
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          git
          gnugrep
          gum
          jq
          openssh
          sops
          ssh-to-age
        ];
        text = builtins.readFile ../scripts/new-host.sh;
      });
    };
  };
}
