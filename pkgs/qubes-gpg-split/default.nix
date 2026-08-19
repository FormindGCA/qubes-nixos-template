{
  lib,
  fetchFromGitHub,
  resholve,
  stdenv,
  coreutils,
  qubes-core-qrexec,
  gnupg,
  libnotify,
  pandoc,
  zenity,
}:
let
  qubesLib = import ../lib.nix {inherit lib fetchFromGitHub;};
in
resholve.mkDerivation rec {
  pname = "qubes-gpg-split";
  version = "2.0.86";

  src = qubesLib.fetchFromQubes {
    repo = "qubes-app-linux-split-gpg";
    inherit version;
    hash = "sha256-ho5xEiNBbjMmSd1x7VHO/KXadhJmn0U6sMEUUw0WQUo=";
  };

  postPatch = ''
    substituteInPlace src/gpg-client.c --replace-fail \
      '#define QREXEC_CLIENT_PATH "/usr/lib/qubes/qrexec-client-vm"' \
      '#define QREXEC_CLIENT_PATH "${qubes-core-qrexec}/bin/qrexec-client-vm"'
  '';

  buildInputs = [
    qubes-core-qrexec
    gnupg
  ];

  nativeBuildInputs = [
    pandoc
  ];

  buildPhase = ''
    make
  '';

  installPhase = ''
    make install-vm \
        DESTDIR="$out" \
        LIBDIR=/lib \
        USRLIBDIR=/lib \
        SYSLIBDIR=/lib

    mv $out/usr/bin $out/bin
    mv $out/usr/share $out/share
    substituteInPlace $out/etc/qubes-rpc/qubes.Gpg \
      --replace-fail '#!/bin/sh' '#!${stdenv.shell}' \
      --replace-fail /usr/lib/qubes-gpg-split/gpg-server $out/lib/qubes-gpg-split/gpg-server \
      --replace-fail /usr/bin/gpg2 ${gnupg}/bin/gpg \
      --replace-fail 'stat -c' '${coreutils}/bin/stat -c' \
      --replace-fail 'date +%s' '${coreutils}/bin/date +%s' \
      --replace-fail 'touch "$stat_file"' '${coreutils}/bin/touch "$stat_file"' \
      --replace-fail 'zenity --question' '${zenity}/bin/zenity --question' \
      --replace-fail 'notify-send ' '${libnotify}/bin/notify-send '
    substituteInPlace $out/etc/qubes-rpc/qubes.GpgImportKey \
      --replace-fail '#!/bin/sh' '#!${stdenv.shell}' \
      --replace-fail /usr/bin/gpg2 ${gnupg}/bin/gpg
    rm -rf $out/usr
  '';

  solutions = {
    default = {
      scripts = [
        "bin/qubes-gpg-client-wrapper"
        "bin/qubes-gpg-import-key"
        "etc/profile.d/qubes-gpg.sh"
      ];
      interpreter = "none";
      fix = {
        source = ["/etc/profile.d/qubes-gpg.sh"];
        "/usr/bin/gpg" = true;
        "/usr/lib/qubes/qrexec-client-vm" = true;
      };
      inputs = [
        "bin"
        "etc/profile.d"
        coreutils
        gnupg
        qubes-core-qrexec
      ];
      execer = [
        "cannot:bin/qubes-gpg-client"
        "cannot:bin/qubes-gpg-import-key"
        "cannot:${gnupg}/bin/gpg"
        "cannot:${qubes-core-qrexec}/bin/qrexec-client-vm"
      ];
    };
  };

  meta = qubesLib.meta "Qubes service for splitting GnuPG private-key operations into a separate qube";
}
