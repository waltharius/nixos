{
  lib,
  fetchurl,
  python3Packages,
  gobject-introspection,
  gtk3,
  wrapGAppsHook3,
  gdk-pixbuf,
  libappindicator,
  librsvg,
  libnotify,
}:
python3Packages.buildPythonApplication rec {
  pname = "solaar";
  version = "1.1.19rc1";

  src = fetchurl {
    url = "https://github.com/pwr-Solaar/Solaar/archive/refs/tags/${version}.tar.gz";
    hash = "sha256-Ucx6d+OwrZ/iy7tKUKTEJzY7tDTjBu83ydjGqJolYSE=";
  };

  outputs = ["out" "udev"];

  pyproject = true;
  build-system = with python3Packages; [setuptools];

  nativeBuildInputs = [
    gdk-pixbuf
    gobject-introspection
    wrapGAppsHook3
  ];

  buildInputs = [
    libappindicator
    librsvg
    libnotify
  ];

  propagatedBuildInputs = with python3Packages; [
    evdev
    gtk3
    psutil
    pygobject3
    pyudev
    pyyaml
    xlib
    dbus-python
    typing-extensions
  ];

  postInstall = ''
    ln -s $out/bin/solaar $out/bin/solaar-cli
    install -Dm444 -t $udev/etc/udev/rules.d rules.d-uinput/*.rules
  '';

  doCheck = false;

  meta = with lib; {
    description = "Linux device manager for Logitech devices";
    homepage = "https://pwr-solaar.github.io/Solaar/";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
