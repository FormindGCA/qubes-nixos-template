{
  lib,
  fetchFromGitHub,
  resholve,
  coreutils,
  qubes-core-qrexec,
  gnupg,
  pandoc,
  rev ? null,
}:
let
  qubesLib = import ../lib.nix {inherit lib;};
in
resholve.mkDerivation rec {
  pname = "qubes-gpg-split";
  version = "2.0.84";

  src = fetchFromGitHub {
    owner = "QubesOS";
    repo = "qubes-app-linux-split-gpg";
    rev = if rev != null then rev else "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
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
    # NOTE: tmpfiles.d integration would be needed to use a NixOS qube as the GPG domain (key holder).
    # Currently only client-side GPG splitting is supported.
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
        # NOTE: client-only mode. qubes-gpg-import-key passes absolute paths to qrexec-client-vm,
        # but the execer correctly allows execution even when exact arguments aren't known.
        "cannot:${qubes-core-qrexec}/bin/qrexec-client-vm"
      ];
    };
  };

  meta = qubesLib.meta "Qubes service for splitting GnuPG private-key operations into a separate qube";
}
