# packages/pcmanfm-qt-fixed/default.nix
#
# nixpkgs#306366: wrapQtAppsHook hides the real executable behind a
# dot-prefixed filename (".pcmanfm-qt-wrapped"). Qt's Wayland app_id
# fallback (QFileInfo(applicationFilePath()).baseName()) returns an EMPTY
# string for such a name, so GNOME/Mutter never sees a valid wm_class.
#
# We do NOT touch or binary-patch the original, hook-generated wrapper —
# doing that with `sed` corrupts it when the replacement string has a
# different byte length, because modern wrapQtAppsHook produces a
# COMPILED (not shell-script) wrapper. Instead we build a brand-new,
# separate launcher from scratch with `makeWrapper`, reusing the same
# Qt environment variables (qtWrapperArgs) and pointing it at a copy of
# the real binary under a name that does not start with a dot.
{
  pcmanfm-qt,
  makeWrapper,
}:
pcmanfm-qt.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [makeWrapper];
  postFixup =
    (old.postFixup or "")
    + ''
      hidden="$out/bin/.pcmanfm-qt-wrapped"
      if [ -e "$hidden" ]; then
        mkdir -p "$out/libexec"
        cp "$hidden" "$out/libexec/pcmanfm-qt-raw"
        makeWrapper "$out/libexec/pcmanfm-qt-raw" "$out/bin/pcmanfm-qt-unwrapped" "''${qtWrapperArgs[@]}"
      else
        echo "pcmanfm-qt-fixed: hidden wrapped binary not found at $hidden — check wrapQtAppsHook's naming convention" >&2
        exit 1
      fi
    '';
})
