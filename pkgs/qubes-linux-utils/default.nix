{callPackage, rev ? null}:
callPackage ./generic.nix {
  version = "4.3.18";
  hash = "sha256-psDPQCzburVJ/RmMx9XI09cf+A223pr4K6hs8l+KAqc=";
  inherit rev;
}
