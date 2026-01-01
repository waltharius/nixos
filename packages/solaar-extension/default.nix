{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "gnome-shell-extension-solaar";
  version = "4";

  src = fetchFromGitHub {
    owner = "sidevesh";
    repo = "solaar-extension-for-gnome";
    rev = "56377ee7cc375b4260d7713483013000b213b185";
    hash = "sha256-n5+C/fTfQz2t1TjT3eFv+s5D/K/lE/d/S/X/o/C/h/g=";
  };

  uuid = "solaar-extension@sidevesh";

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
