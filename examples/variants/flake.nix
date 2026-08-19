{
  description = "Extended Qubes NixOS configuration examples";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

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
      overlays = [qubes-nixos-template.overlays.default];
    };
    qubesModules = [
      qubes-nixos-template.nixosModules.default
      qubes-nixos-template.nixosProfiles.default
      # Inherit the base configuration
      (import "${qubes-nixos-template}/examples/configuration.nix")
      ./common.nix
    ];
  in {
    nixosConfigurations = {

      # Used as a based template with a maximum of tools
      # AppVMs will inherit the cache client config
      nix-template = nixpkgs.lib.nixosSystem {
        inherit pkgs system;
        modules = qubesModules ++ [
          ./super-template.nix
          ./qrexec-cache-client.nix
        ];
      };

      # Only for the caching server
      # Should be run as a StandaloneVM
      nix-cache = nixpkgs.lib.nixosSystem {
        inherit pkgs system;
        modules = qubesModules ++ [./qrexec-cache-server.nix];
      };
    };
  };
}
