{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "gnome-shell-extension-solaar";
  version = "2.1.3+5";

  src = fetchFromGitHub {
    owner = "sidevesh";
    repo = "solaar-extension-for-gnome";
    rev = "refs/tags/${version}";
    hash = "sha256-sueTC3YRyIiOrLNAi0G3bWfxn/ml4Bwzw1qlWpBZJys=";
  };
  uuid = "solaar-extension@sidevesh";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/gnome-shell/extensions/${uuid}
    cp -r solaar-extension@sidevesh/* $out/share/gnome-shell/extensions/${uuid}/
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
