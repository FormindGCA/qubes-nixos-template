{
  description = "Example nixos templatevm configuration";

  inputs = {
    # Base pkgs
    nixpkgs.url = "nixpkgs/nixos-unstable";

    # Use your fork if you need to pin the qubes pkgs version
    qubes-nixos-template = {
      url = "github:FormindGCA/qubes-nixos-template";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    qubes-nixos-template,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        qubes-nixos-template.overlays.default
      ];
    };
  in {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        inherit pkgs system;
        modules = [
          qubes-nixos-template.nixosModules.default
          qubes-nixos-template.nixosProfiles.default
          ./configuration.nix
        ];
      };
    };
  };
}
