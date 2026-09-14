{callPackage, rev ? null}:
callPackage ./generic.nix {
  version = "4.3.21";
  hash = "sha256-XQcoN/xod32bd0SlasiC5+SQt/WgbDQvrCmPmUKswJc=";
  inherit rev;
}
