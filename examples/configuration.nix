{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
    };
  };

  system.stateVersion = "26.05";

  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    xterm
  ];
}
