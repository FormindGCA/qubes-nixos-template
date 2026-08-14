{
  description = "Example mission-specific tool";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = {self, nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system} = {
      mission-hash = pkgs.writeShellApplication {
        name = "mission-hash";
        runtimeInputs = [pkgs.openssl];
        text = ''
          exec openssl dgst -sha256 "$@"
        '';
      };
      default = self.packages.${system}.mission-hash;
    };
  };
}
