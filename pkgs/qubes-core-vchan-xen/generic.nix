{
  lib,
  stdenv,
  fetchFromGitHub,
  xen,
  version,
  hash,
  rev ? null,
}:
let
  qubesLib = import ../lib.nix {inherit lib;};
in
stdenv.mkDerivation rec {
  pname = "qubes-core-vchan-xen";
  inherit version;

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = if rev != null then rev else "v${version}";
    inherit hash;
  };
  buildInputs = [xen];

  buildPhase = ''
    make all PREFIX=/ LIBDIR="$out/lib" INCLUDEDIR="$out/include"
  '';

  installPhase = ''
    make install DESTDIR=$out PREFIX=/
  '';

  env.CFLAGS = "-DHAVE_XC_DOMAIN_GETINFO_SINGLE";

  meta = qubesLib.meta "Libraries required for the higher-level Qubes daemons and tools";
}
