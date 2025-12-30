{ stdenv }:
stdenv.mkDerivation rec {
  name = "keycloak_theme_custom";
  version = "1.0";

  src = ./themes/custom;

  nativeBuildInputs = [ ];
  buildInputs = [ ];

  installPhase = ''
    mkdir -p $out
    cp -a login $out
  '';
}
