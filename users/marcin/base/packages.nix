# users/marcin/base/packages.nix
#
# Home packages for marcin — applications and tools installed for every
# host. This list intentionally includes only packages that are wanted
# on all machines. Host-specific packages (e.g. GPU monitoring tools)
# belong in users/marcin/profiles/<hostname>.nix.
#
# Packages provided by dedicated HM program modules (git, yazi, atuin,
# starship, …) are NOT listed here to avoid double-installation.
{
  pkgs,
  pkgs-unstable,
  customPkgs,
  config,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # --- custom packages ---
    customPkgs.rebuild-and-diff
    customPkgs.solaar-stable

    # --- GUI applications ---
    blanket
    signal-desktop
    pkgs-unstable.brave
    gnome-secrets
    pkgs-unstable.vivaldi
    shotwell
    nextcloud-client
    foliate
    freerdp

    # --- productivity & office ---
    pkgs-unstable.silverbullet
    libreoffice-fresh
    pkgs-unstable.zotero
    pkgs-unstable.obsidian
    thunderbird-latest
    onlyoffice-desktopeditors
    flameshot

    # --- pdf-tools native compilation dependencies ---
    poppler
    poppler.dev
    glib.dev
    cairo.dev
    pkg-config
    libpng

    # --- media & entertainment ---
    spotify
    spotify-player
    gnome-mahjongg
    gnome-podcasts
    gnome-solanum

    # --- emacs + writing ---
    emacs
    texlive.combined.scheme-full
    gnupg
    pinentry-gnome3

    # --- development tools ---
    zip
    unzip
    ripgrep
    fd
    tree
    curl
    git

    # --- shell utilities ---
    ptyxis
    blesh
    eza
    zoxide
    starship
    fastfetch
    atuin
    btop
    lsof
    procfd
    usbutils
    pciutils
    wget
    rclone
    rclone-ui
    dig
    openssl
    pkgs-unstable.nb
    ocrmypdf
    tesseract
    libsecret
    pdftk
    qpdf
    ghostscript

    # --- nix tools ---
    nix-prefetch-github
    sops
    age
    nil
    nixpkgs-fmt
    nvd
    nh
    colmena

    # --- file manager ---
    yazi

    # --- fonts ---
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    google-fonts
    liberation_ttf

    # --- language / spell checking ---
    # hunspell with UTF-8 capable dictionaries.
    # pl_PL from Nixpkgs is always ISO8859-2; we provide a converted UTF-8
    # copy via home.activation (see below). en_GB-large is already UTF-8.
    (hunspell.withDicts (dicts: with dicts; [en_GB-large]))
    languagetool
  ];

  # ---------------------------------------------------------------------------
  # Hunspell UTF-8 dictionary for pl_PL
  #
  # hunspellDicts.pl_PL ships ISO8859-2 which causes iconv errors at runtime.
  # We convert the .aff and .dic files to UTF-8 once, storing them in
  # ~/.local/share/hunspell/.  Emacs points DICPATH there (see 03-spelling.el).
  # The activation re-runs only when the source file is newer than the output.
  # ---------------------------------------------------------------------------
  home.activation.hunspellUtf8 = lib.hm.dag.entryAfter ["writeBoundary"] ''
    SRC="/etc/profiles/per-user/${config.home.username}/share/hunspell"
    DST="$HOME/.local/share/hunspell"
    $DRY_RUN_CMD mkdir -p "$DST"

    for lang in pl_PL; do
      if [ "$SRC/''${lang}.aff" -nt "$DST/''${lang}.aff" ] || [ ! -f "$DST/''${lang}.aff" ]; then
        $DRY_RUN_CMD ${pkgs.glibc.bin}/bin/iconv -f ISO8859-2 -t UTF-8 \
          "$SRC/''${lang}.aff" \
          | ${pkgs.gnused}/bin/sed 's/^SET ISO8859-2/SET UTF-8/' \
          > "$DST/''${lang}.aff"
        $DRY_RUN_CMD ${pkgs.glibc.bin}/bin/iconv -f ISO8859-2 -t UTF-8 \
          "$SRC/''${lang}.dic" > "$DST/''${lang}.dic"
      fi
    done
  '';
}
