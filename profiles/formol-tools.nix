{ config, lib, pkgs, formol, ... }:
let
  # Resolve the filesystem path of the AT-formol images/nix flake
  formolPath = if lib.hasAttr "outPath" formol then formol.outPath else formol;

  # Import a category file and normalize to a list of packages
  importCategory = name: let
    path = formolPath + "/tools-packages/" + name + ".nix";
    val = import path { inherit pkgs; };
  in if builtins.isList val then val
     else if builtins.isAttrs val && val ? packages then val.packages
     else [];
in {
  options.formol.tools = {
    enable = lib.mkEnableOption "Enable AT-formol tooling baseline";
    categories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "generic" "code" "network" "linux" "web" "pwn" "android" "cloud" "ad" ];
      description = "Subset of tool categories to include from AT-formol.";
    };
  };

  config = lib.mkIf config.formol.tools.enable {
    environment.systemPackages = let
      chosen = map importCategory config.formol.tools.categories;
    in lib.unique (lib.concatLists chosen);
  };
}
