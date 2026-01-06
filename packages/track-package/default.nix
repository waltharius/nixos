{pkgs, ...}: let
  lib-sh = pkgs.writeText "lib.sh" (builtins.readFile ./lib.sh);
  schema-sql = pkgs.writeText "schema.sql" (builtins.readFile ./schema.sql);
in
  pkgs.writeShellApplication {
    name = "track-package";

    runtimeInputs = with pkgs; [
      nix
      sqlite
      coreutils
      gnugrep
      gawk
      findutils
    ];

    text =
      builtins.replaceStrings
      ["@LIB_PATH@" "@SCHEMA_PATH@"]
      ["${lib-sh}" "${schema-sql}"]
      (builtins.readFile ./track-package.sh);
  }
