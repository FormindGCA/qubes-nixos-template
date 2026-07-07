{
  lib,
  stdenv,
  fetchFromGitHub,
  version,
  hash,
  rev ? null,
}:
let
  qubesLib = import ../lib.nix {inherit lib fetchFromGitHub;};
in
stdenv.mkDerivation rec {
  pname = "qubes-gui-common";
  inherit version;

  src = qubesLib.fetchFromQubes {repo = pname; inherit version hash rev;};

  buildPhase = ''
    true
  '';

  installPhase = ''
    mkdir -p $out/include
    cp include/*.h $out/include/
  '';

  meta = qubesLib.meta "Common files for Qubes GUI - protocol headers";
}
