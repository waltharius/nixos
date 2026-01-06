{pkgs, ...}:
pkgs.writeShellApplication {
  name = "track-package-simple";
  
  runtimeInputs = with pkgs; [
    nix
    coreutils
    gnugrep
    gawk
  ];

  text = builtins.readFile ./track-package-simple.sh;
}
