{callPackage, rev ? null}:
callPackage ./generic.nix {
  version = "4.3.15";
  hash = "sha256-DrgJFtPb1YHieDffs3RD24hjxcX347eZlaZNO/3/MXk=";
  inherit rev;
}
