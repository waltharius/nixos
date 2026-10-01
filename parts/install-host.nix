# parts/install-host.nix
#
#   nix run .#install-host -- <host> root@<address>
#     install a host registered with new-host using nixos-anywhere
#     (scripts/install-host.sh, docs/NEW-HOST.md)
{lib, ...}: {
  perSystem = {pkgs, ...}: {
    apps.install-host = {
      type = "app";
      meta.description = "Install a host registered with new-host using nixos-anywhere";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "install-host";
        # nix comes from the caller's PATH.
        runtimeInputs = with pkgs; [
          coreutils
          git
          gnugrep
          gum
          jq
          mkpasswd
          nixos-anywhere
          openssh
          sops
        ];
        text = builtins.readFile ../scripts/install-host.sh;
      });
    };
  };
}
