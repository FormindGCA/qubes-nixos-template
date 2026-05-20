{
  callPackage,
  enableNetworking ? false,
  rev ? null,
}:
callPackage ./generic.nix {
  version = "4.3.43";
  hash = "sha256-9hWuAS2eijRQSw+Bx05TqDLSUPLyBpXK/tKLuHsWjjY=";
  inherit enableNetworking;
  rev = rev;
}
