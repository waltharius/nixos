# modules/groups/emacs/home.nix
#
# Group `emacs`, user part. The Emacs configuration itself lives in a
# separate repository (~/.emacs.d); this group provides Emacs and the
# external programs that configuration relies on.
{
  config,
  pkgs,
  ...
}: let
  # ---------------------------------------------------------------------------
  # Polish Hunspell dictionary converted to UTF-8 at build time
  #
  # hunspellDicts.pl_PL (LibreOffice dictionaries) is ISO8859-2. Hunspell on
  # NixOS fails to convert it for a UTF-8 client: Emacs starts it with
  # `-i UTF-8', Hunspell prints "error - iconv: ISO8859-2 -> UTF-8", and
  # ispell rejects the process, so flyspell cannot be enabled.
  #
  # `hunspell.withDicts' wraps the binary with
  # `--prefix DICPATH : <env>/share/hunspell', so its dictionaries are always
  # found before any directory a client adds to DICPATH. A converted copy
  # outside the store (the former home.activation.hunspellUtf8, writing
  # ~/.local/share/hunspell) is therefore never read. Converting here puts
  # the UTF-8 files in that env instead: part of the generation, rebuilt on
  # every nixpkgs update, covered by rollback.
  #
  # The build fails if the source header is not ISO8859-2 or the result is
  # not valid UTF-8, so a change upstream is noticed at rebuild time and
  # not as missing underlines in Emacs.
  # ---------------------------------------------------------------------------
  hunspellPlUtf8 = let
    src = pkgs.hunspellDicts.pl_PL;
  in
    pkgs.runCommand "hunspell-dict-pl-pl-utf8-${src.version}" {} ''
      set -euo pipefail
      src_dir=${src}/share/hunspell
      out_dir=$out/share/hunspell
      mkdir -p "$out_dir"

      if ! grep -q '^SET ISO8859-2' "$src_dir/pl_PL.aff"; then
        echo "pl_PL.aff is not declared ISO8859-2; review the conversion" >&2
        exit 1
      fi

      ${pkgs.glibc.bin}/bin/iconv -f ISO8859-2 -t UTF-8 "$src_dir/pl_PL.aff" \
        | sed 's/^SET ISO8859-2/SET UTF-8/' > "$out_dir/pl_PL.aff"
      ${pkgs.glibc.bin}/bin/iconv -f ISO8859-2 -t UTF-8 "$src_dir/pl_PL.dic" \
        > "$out_dir/pl_PL.dic"

      # Sanity checks: header switched, both files valid UTF-8.
      grep -q '^SET UTF-8' "$out_dir/pl_PL.aff"
      ${pkgs.glibc.bin}/bin/iconv -f UTF-8 -t UTF-8 "$out_dir/pl_PL.aff" > /dev/null
      ${pkgs.glibc.bin}/bin/iconv -f UTF-8 -t UTF-8 "$out_dir/pl_PL.dic" > /dev/null
    '';
in {
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
    # hunspell with UTF-8 dictionaries only: en_GB-large is UTF-8 upstream
    # (installed as en_GB.aff/.dic), pl_PL is the build-time conversion
    # above. Emacs: ~/.emacs.d/modules/03-spelling.el.
    (hunspell.withDicts (dicts: [dicts.en_GB-large hunspellPlUtf8]))
    languagetool
  ];

  # Required by the LanguageTool Emacs client to locate the JAR.
  home.sessionVariables.LANGUAGETOOL_JAR = "${pkgs.languagetool}/share/languagetool-commandline.jar";

  # pdf-tools compiles its server on first use and finds the libraries
  # listed above through pkg-config in the user profile.
  programs.bash.bashrcExtra = ''
    export PKG_CONFIG_PATH="/etc/profiles/per-user/${config.home.username}/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  '';
}
