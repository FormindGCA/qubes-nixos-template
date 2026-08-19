{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
    options.services.qubes.db.enable = mkEnableOption "the qubes db daemon";

    config = mkIf config.services.qubes.db.enable {
      boot.kernelModules = ["xen_gntdev" "xen_evtchn"];

      environment.systemPackages = [
        pkgs.qubes-core-qubesdb
      ];
      systemd.services.qubes-db = {
        description = "Qubes DB agent";
        after = ["systemd-modules-load.service"];

        unitConfig = {
          DefaultDependencies = false;
        };

        serviceConfig = {
          Group = "qubes";
          Type = "notify";
          LogsDirectory = "qubes";
          RuntimeDirectory = "qubes";
          RuntimeDirectoryMode = "0775";
          ExecStart = "${pkgs.qubes-core-qubesdb}/bin/qubesdb-daemon 0";
        };
      };
    };
  }
