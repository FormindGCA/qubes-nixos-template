{
  config,
  lib,
  pkgs,
  ...
}: let
  package = pkgs.qubes-video-companion;
in {
  options.services.qubes.videoCompanion.enable =
    lib.mkEnableOption "Qubes Video Companion";

  config = lib.mkIf config.services.qubes.videoCompanion.enable {
    services.qubes.qrexec.enable = true;
    services.qubes.qrexec.packages = [package];
    services.udev.packages = [package];
    systemd.packages = [package];

    environment.systemPackages = [package pkgs.v4l-utils];
    environment.etc = {
      "qubes/rpc-config/qvc.Webcam".source = "${package}/etc/qubes/rpc-config/qvc.Webcam";
      "qubes/rpc-config/qvc.ScreenShare".source = "${package}/etc/qubes/rpc-config/qvc.ScreenShare";
    };

    boot.kernelModules = ["v4l2loopback"];
    boot.extraModprobeConfig = "options v4l2loopback devices=0";
  };
}
