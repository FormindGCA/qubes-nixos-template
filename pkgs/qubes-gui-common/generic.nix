{
  lib,
  stdenv,
  fetchFromGitHub,
  version,
  hash,
  rev ? null,
}:
let
  qubesLib = import ../lib.nix {inherit lib;};
in
stdenv.mkDerivation rec {
  pname = "qubes-gui-common";
  inherit version;

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = if rev != null then rev else "v${version}";
    inherit hash;
  };

  buildPhase = ''
    true
  '';

  installPhase = ''
    mkdir -p $out/include
    cp include/*.h $out/include/
  '';

  meta = qubesLib.meta "Common files for Qubes GUI - protocol headers";
}
