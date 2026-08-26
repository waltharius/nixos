# modules/home/desktop/qt-theming.nix
#
# Without this, Qt applications (e.g. PCManFM-Qt) have no bridge to the
# GTK icon theme that GNOME already provides (Adwaita). Qt's own icon
# lookup only searches "hicolor", which is just a fallback skeleton where
# individual apps install their own icons — it does not contain generic
# freedesktop icon names like "computer" or "drive-harddisk". Setting
# platformTheme to "gtk3" makes Qt resolve QIcon::fromTheme() through the
# same icon theme GTK/GNOME apps already use.
{
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };
}
