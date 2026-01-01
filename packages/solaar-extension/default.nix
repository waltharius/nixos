{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "gnome-shell-extension-solaar";
  version = "unstable-2024-03-03";

  src = fetchFromGitHub {
    owner = "Svenum";
    repo = "Solaar-Extension";
    rev = "3196c8130e9227c24f6f874f67623919b48b6c45";
    hash = "sha256-N4/RzT3n/L0t8K3zGzQWd4PzFv6aX+5Yg5o2K5z6/5o=";
  };

  uuid = "solaar-extension@felix.struemer.de";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/gnome-shell/extensions/${uuid}
    cp -r * $out/share/gnome-shell/extensions/${uuid}
    runHook postInstall
  '';

  passthru = {
    extensionUuid = uuid;
  };

  meta = with lib; {
    description = "Solaar GNOME Shell Extension";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
