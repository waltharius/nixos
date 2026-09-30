# modules/groups/office/home.nix
#
# Group `office`, user part: office suites, bibliography, e-books,
# screenshots, a focus timer and PDF tools.
{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages = with pkgs; [
    libreoffice-fresh
    onlyoffice-desktopeditors
    pkgs-unstable.zotero
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
