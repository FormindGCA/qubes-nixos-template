{
  callPackage,
  enableNetworking ? false,
  rev ? null,
}:
callPackage ./generic.nix {
  version = "4.3.48";
  hash = "sha256-g8WjsPvGHgLYCCXWpqXKZpUt8AJkDZi7WrYo37t/ers=";
  inherit enableNetworking rev;
}
