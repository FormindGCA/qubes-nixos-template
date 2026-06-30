{
  callPackage,
  enableNetworking ? false,
  rev ? null,
}:
callPackage ./generic.nix {
  version = "4.3.46";
  hash = "sha256-KKuEt+X3L4H3HVAkJru9fxKa05xuxlcex+uQWPpBPVw=";
  inherit enableNetworking;
  rev = rev;
}
