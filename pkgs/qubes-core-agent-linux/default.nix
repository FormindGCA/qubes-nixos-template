{
  callPackage,
  enableNetworking ? false,
  rev ? null,
}:
callPackage ./generic.nix {
  version = "4.3.46";
  hash = "sha256-3unoaXYQ3FU0/vMkofQmppokAzWHksH9NlmjLj9WNrw=";
  inherit enableNetworking;
  rev = rev;
}
