{
  callPackage,
  enableNetworking ? false,
  rev ? null,
}:
callPackage ./generic.nix {
  version = "4.2.45";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
  inherit enableNetworking;
  rev = rev;
}
