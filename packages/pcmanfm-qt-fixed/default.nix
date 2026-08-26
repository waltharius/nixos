# packages/pcmanfm-qt-fixed/default.nix
#
# nixpkgs#306366: wrapQtAppsHook hides the real executable behind a
# dot-prefixed filename (".pcmanfm-qt-wrapped"). Qt's Wayland app_id
# fallback (QFileInfo(applicationFilePath()).baseName()) returns an EMPTY
# string for such a name, so GNOME/Mutter never sees a valid wm_class.
# We let the hook wrap normally (correct QT_PLUGIN_PATH, etc.), then
# rename the hidden binary to something without a leading dot and patch
# the generated wrapper script to point at the new path.
{pcmanfm-qt}:
pcmanfm-qt.overrideAttrs (old: {
  postFixup =
    (old.postFixup or "")
    + ''
      hidden=$(compgen -G "$out/bin/.pcmanfm-qt-wrapped*" | head -n1)
      if [ -n "$hidden" ]; then
        fixed="$out/bin/pcmanfm-qt-unwrapped"
        mv "$hidden" "$fixed"
        sed -i "s#$hidden#$fixed#" "$out/bin/pcmanfm-qt"
      else
        echo "pcmanfm-qt-fixed: hidden wrapped binary not found — check wrapQtAppsHook's naming convention" >&2
        exit 1
      fi
    '';
})
