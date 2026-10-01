# modules/groups/emacs/home.nix
#
# Group `emacs`, user part. The Emacs configuration itself lives in a
# separate repository (~/.emacs.d); this group provides Emacs and the
# external programs that configuration relies on.
{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    emacs

    # --- pdf-tools native compilation dependencies ---
    poppler
    poppler.dev
    (pkgs.lib.hiPrio poppler-utils)
    glib.dev
    cairo.dev
    pkg-config
    libpng

    # --- encryption (EasyPG) ---
    gnupg
    pinentry-gnome3

    # python3 with PyYAML: the ~/.emacs.d pre-commit checks
    # (hooks/lint.py, standard library only) and tools/obsidian_import.py,
    # which parses the YAML front matter Obsidian writes. Only the wrapped
    # interpreter is listed - adding plain python3 next to it would put two
    # bin/python3 into the profile.
    (python3.withPackages (ps: with ps; [pyyaml]))
    # pandoc: markdown -> org conversion for the Obsidian import
    # (tools/obsidian_import.py).
    pandoc

    # --- language / spell checking ---
    # hunspell with UTF-8 capable dictionaries.
    # pl_PL from Nixpkgs is always ISO8859-2; a converted UTF-8 copy is
    # made by home.activation (see below). en_GB-large is already UTF-8.
    (hunspell.withDicts (dicts: with dicts; [en_GB-large pl_PL]))
    languagetool
  ];

  # Required by the LanguageTool Emacs client to locate the JAR.
  home.sessionVariables.LANGUAGETOOL_JAR = "${pkgs.languagetool}/share/languagetool-commandline.jar";

  # pdf-tools compiles its server on first use and finds the libraries
  # listed above through pkg-config in the user profile.
  programs.bash.bashrcExtra = ''
    export PKG_CONFIG_PATH="/etc/profiles/per-user/${config.home.username}/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  '';

  # ---------------------------------------------------------------------------
  # Hunspell UTF-8 dictionary for pl_PL
  #
  # hunspellDicts.pl_PL ships ISO8859-2 which causes iconv errors at runtime.
  # The .aff and .dic files are converted to UTF-8 once and stored in
  # ~/.local/share/hunspell/. Emacs points DICPATH there (see 03-spelling.el).
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
