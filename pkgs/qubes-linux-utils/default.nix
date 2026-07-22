{callPackage, rev ? null}:
callPackage ./generic.nix {
  version = "4.3.18";
  hash = "sha256-CfzzzQKYlzujDKID7GJ+GEKFjccBjb1cUHiTm0lgOgE=";
  inherit rev;
}
