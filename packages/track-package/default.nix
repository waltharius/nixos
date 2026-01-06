{pkgs, ...}:
pkgs.stdenv.mkDerivation {
  pname = "track-package";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [pkgs.makeWrapper];

  buildInputs = with pkgs; [
    bash
    sqlite
    nix
    coreutils
    gnugrep
    gawk
    findutils
  ];

  installPhase = ''
    mkdir -p $out/bin $out/share/track-package

    # Install SQL schema
    cp schema.sql $out/share/track-package/

    # Install library with substitutions
    substitute lib.sh $out/share/track-package/lib.sh \
      --replace "#!/usr/bin/env bash" "#!${pkgs.bash}/bin/bash"

    # Install main script with path substitutions
    substitute track-package.sh $out/bin/track-package \
      --replace "@LIB_PATH@" "$out/share/track-package/lib.sh" \
      --replace "@SCHEMA_PATH@" "$out/share/track-package/schema.sql" \
      --replace "#!/usr/bin/env bash" "#!${pkgs.bash}/bin/bash"

    chmod +x $out/bin/track-package

    # Wrap with runtime dependencies
    wrapProgram $out/bin/track-package \
      --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
      nix
      coreutils
      gnugrep
      gawk
      findutils
      sqlite
    ])}
  '';

  meta = with pkgs.lib; {
    description = "Track package version history across NixOS generations";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
