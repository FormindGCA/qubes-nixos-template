{
  lib,
  fetchFromGitHub,
  resholve,
  bash,
  coreutils,
  glibc,
  lsb-release,
  pam,
  pandoc,
  pkg-config,
  python3,
  python3Packages,
  qubes-core-vchan-xen,
  util-linux,
  version,
  hash,
  rev ? null,
}:
let
  qubesLib = import ../lib.nix {inherit lib;};
in
resholve.mkDerivation rec {
  pname = "qubes-core-qrexec";
  inherit version;

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = pname;
    rev = if rev != null then rev else "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [
    bash
    pkg-config
    python3Packages.distutils
    python3Packages.setuptools
    lsb-release
    pandoc
  ];

  buildInputs = [
    glibc
    qubes-core-vchan-xen
    python3
    pam
  ];

  buildPhase = ''
    make all-base
    make all-vm
  '';

  installPhase = ''
    make install-base DESTDIR="$out" PREFIX=/ PYTHON_PREFIX_ARG="--prefix ." LIBDIR="/lib" SYSLIBDIR="/lib"
    make install-vm DESTDIR="$out" PREFIX=/ PYTHON_PREFIX_ARG="--prefix ." LIBDIR="/lib" SYSLIBDIR="/lib"

    mv "$out/usr/bin" "$out/bin"
    mv "$out/usr/include" "$out/include"
    mv "$out/usr/lib/qubes" "$out/lib/qubes"
    mv "$out/usr/share" "$out/share"

    substituteInPlace "$out/etc/xdg/autostart/qrexec-policy-agent.desktop" --replace-fail '/usr/lib/qubes/qrexec-policy-agent-autostart' "$out/lib/qubes/qrexec-policy-agent-autostart"

    rm -rf "$out/usr"
  '';

  solutions = {
    default = {
      scripts = ["lib/qubes/qubes-rpc-multiplexer"];
      interpreter = "none";
      inputs = [coreutils util-linux];
    };
  };

  meta = qubesLib.meta "The Qubes qrexec files (qube side)";
}
