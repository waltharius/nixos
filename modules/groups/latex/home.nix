# modules/groups/latex/home.nix
#
# Group `latex`, user part. scheme-full is several gigabytes, which is why
# LaTeX is not part of `office` or `emacs`.
{pkgs, ...}: {
  home.packages = [pkgs.texlive.combined.scheme-full];
}
