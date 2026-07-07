{
  lib,
  stdenv,
  fetchFromGitHub,
  resholve,
  coreutils,
  gnugrep,
  icu,
  lsb-release,
  kmod,
  graphicsmagick,
  pkg-config,
  python3Packages,
  qubes-core-vchan-xen,
  qubes-core-qubesdb,
  xen,
  version,
  hash,
  rev ? null,
}: let
  qubesLib = import ../lib.nix {inherit lib;};
  name = "qubes-linux-utils";
  resholved = resholve.mkDerivation rec {
    inherit version;
    pname = "${name}-resholved";

    src = fetchFromGitHub {
      owner = "QubesOS";
      repo = name;
      rev = if rev != null then rev else "v${version}";
      inherit hash;
    };

    nativeBuildInputs =
      [
        icu
        pkg-config
        qubes-core-vchan-xen
        xen
      ]
      ++ (with python3Packages; [
        distutils
        setuptools
      ]);

    buildInputs =
      [
        graphicsmagick
        icu
      ]
      ++ (with python3Packages; [
        pycairo
        pillow
        numpy
      ]);

    postPatch = ''
      substituteInPlace qmemman/Makefile --replace-fail '_XENSTORE_H=$(shell ls /usr/include/xenstore.h)' '_XENSTORE_H=1'
    '';

    buildPhase = ''
      make all
    '';

    installPhase = ''
      make install \
          PYTHON_PREFIX_ARG="--prefix ." \
          DESTDIR="$out" \
          LIBDIR=/lib \
          SYSLIBDIR=/lib \
          BINDIR=/bin \
          SBINDIR=/bin \
          SCRIPTSDIR=/lib/qubes \
          INCLUDEDIR=/include


      mv "$out/usr/lib/systemd" "$out/lib/systemd"

      rm -rf "$out/usr"
    '';

    solutions = {
      default = {
        scripts = [
          "lib/qubes/udev-usb-add-change"
          "lib/qubes/udev-usb-remove"
        ];
        interpreter = "none";
        fix = {
          "/sbin/modprobe" = true;
        };
        inputs = [
          coreutils
          gnugrep
          kmod
          qubes-core-qubesdb
        ];
        execer = [
          "cannot:${kmod}/bin/modprobe"
        ];
      };
    };

    meta = qubesLib.meta "Common Linux files for Qubes VM.";
  };
in
  stdenv.mkDerivation {
    src = resholved;
    inherit version;
    pname = name;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      cp -R $src $out
      substituteInPlace "$out/lib/udev/rules.d/99-qubes-usb.rules" --replace-fail '/usr/lib/qubes/' "${resholved}/lib/qubes/"
      substituteInPlace "$out/lib/udev/rules.d/99-qubes-block.rules" --replace-fail '/usr/lib/qubes/' "${resholved}/lib/qubes/"
    '';

    meta = resholved.meta;
  }
