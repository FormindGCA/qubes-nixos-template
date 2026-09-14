{
  callPackage,
  enableNetworking ? false,
  rev ? null,
}:
callPackage ./generic.nix {
  version = "4.3.47";
  hash = "sha256-NXx+Xk72rBR717KCrRDBcqdHehclUtEedN/BXAurBbE=";
  inherit enableNetworking rev;
}
