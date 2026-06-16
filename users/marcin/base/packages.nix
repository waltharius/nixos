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
    hunspell
    hunspellDicts.en_GB-large
    hunspellDicts.pl_PL
    languagetool
  ];
}
