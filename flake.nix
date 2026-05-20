{
  description = "nixos templatevm configurations";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    # Set this to "release4.3" to build package sources from the Qubes 4.3 branch.
    # Leave null to keep the current pinned v<version> tags.
    qubesBranch = "release4.3";
    qubesPackages = final: prev: {
      qubes-core-qubesdb = prev.callPackage ./pkgs/qubes-core-qubesdb { rev = qubesBranch; };
      qubes-core-vchan-xen = prev.callPackage ./pkgs/qubes-core-vchan-xen { rev = qubesBranch; };
      qubes-core-qrexec = prev.callPackage ./pkgs/qubes-core-qrexec { rev = qubesBranch; };
      qubes-core-agent-linux = prev.callPackage ./pkgs/qubes-core-agent-linux { rev = qubesBranch; };
      qubes-linux-utils = prev.callPackage ./pkgs/qubes-linux-utils { rev = qubesBranch; };
      qubes-gui-common = prev.callPackage ./pkgs/qubes-gui-common { rev = qubesBranch; };
      qubes-gui-agent-linux = prev.callPackage ./pkgs/qubes-gui-agent-linux { rev = qubesBranch; };
      qubes-sshd = prev.callPackage ./pkgs/qubes-sshd {};
      qubes-usb-proxy = prev.callPackage ./pkgs/qubes-usb-proxy { rev = qubesBranch; };
      qubes-gpg-split = prev.callPackage ./pkgs/qubes-gpg-split { rev = qubesBranch; };
    };
    patched-nix-update = final: prev: {
      nix-update =
        prev.nix-update
        .overrideAttrs
        (finalAttrs: previousAttrs: {
          patches = [./pkgs/nix-update/0000-fetch-from-tags.patch];
        });
    };

    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        qubesPackages
        patched-nix-update
      ];
    };
  in rec {
    overlays.default = qubesPackages;
    nixosModules.default = {
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = [
        ./modules/qubes/core.nix
        ./modules/qubes/db.nix
        ./modules/qubes/gui.nix
        ./modules/qubes/networking.nix
        ./modules/qubes/qrexec.nix
        ./modules/qubes/sshd.nix
        ./modules/qubes/updates.nix
        ./modules/qubes/usb.nix
      ];
    };
    nixosProfiles.default = {
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = [
        ./profiles/qubes.nix
      ];
    };
    nixosConfigurations = {
      nixos =
        lib.nixosSystem
        {
          inherit pkgs system;
          modules = [
            self.nixosModules.default
            self.nixosProfiles.default
            ./examples/configuration.nix
          ];
        };
      iso = lib.nixosSystem {
        inherit system;
        specialArgs = {
          targetSystem = nixosConfigurations.nixos;
        };
        modules = [
          ./tools/iso.nix
        ];
      };
    };
    rpm = pkgs.callPackage ./tools/rpm.nix {
      inherit nixpkgs;
      qubesVersion = "4.2.0";
      nixosConfig = nixosConfigurations.nixos;
    };
    iso = nixosConfigurations.iso.config.system.build.isoImage;
    packages.x86_64-linux = pkgs;
  };
}
