# modules/groups/office/home.nix
#
# Group `office`, user part: office suites, bibliography, e-books,
# screenshots, a focus timer, PDF tools and Obsidian (older notes; the
# note-taking tool is Emacs).
{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages = with pkgs; [
    libreoffice-fresh
    onlyoffice-desktopeditors
    pkgs-unstable.zotero
    pkgs-unstable.obsidian
    foliate
    flameshot
    gnome-solanum

    # --- PDF: OCR, splitting/merging, conversion ---
    ocrmypdf
    jbig2enc
    tesseract
    pdftk
    qpdf
    ghostscript
    imagemagick
  ];

  services.flatpak.packages = [
    "io.github.mihnea_radulescu.quickpdfjoin"
  ];
}
