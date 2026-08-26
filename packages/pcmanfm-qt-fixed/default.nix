# packages/pcmanfm-qt-fixed/default.nix
#
# Poprawka na nixpkgs#306366: wrapQtAppsHook od LXQt 2.0.0 (PR #305107)
# nie ustawia poprawnie argv0, przez co PCManFM-Qt zgłasza pusty
# app_id/WM_CLASS na Waylandzie ("<untracked>" w Looking Glass).
# Wyłączamy automatyczne owijanie i robimy je ręcznie z --argv0.
{pcmanfm-qt}:
pcmanfm-qt.overrideAttrs (old: {
  dontWrapQtApps = true;
  postFixup =
    (old.postFixup or "")
    + ''
      wrapQtApp "$out/bin/pcmanfm-qt" --argv0 pcmanfm-qt
    '';
})
