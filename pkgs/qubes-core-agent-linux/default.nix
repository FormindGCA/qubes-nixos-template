{
  callPackage,
  enableNetworking ? false,
  rev ? null,
}:
callPackage ./generic.nix {
  version = "4.2.45";
  hash = "sha256-Eb7ueu1EVnVgudY98od4nsYjxi0jynsbwYXglL7tynA=";
  inherit enableNetworking;
  rev = rev;
}
