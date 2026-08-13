{callPackage, rev ? null}:
callPackage ./generic.nix {
  version = "4.3.19";
  hash = "sha256-DoX4v4g8LWBMbQK7rHgQ+nEbz7v644/+YivgrarCqFo=";
  inherit rev;
}
