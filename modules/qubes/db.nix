{
  config,
  lib,
  pkgs,
  ...
}: let
  init = pkgs.writeShellScriptBin "qubes-db-init" ''
    wait_for_device() {
      local dev="$1"
      local i=0
      while [ ! -e "$dev" ]; do
        if [ "$i" -ge 50 ]; then
          echo "$dev not found" >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/sleep 0.1
        i=$((i + 1))
      done
    }

    ${pkgs.coreutils}/bin/mkdir -p /var/log/qubes
    ${pkgs.coreutils}/bin/mkdir -m 0775 -p /var/run/qubes
    ${pkgs.systemd}/bin/udevadm settle || true
    wait_for_device /dev/xen/evtchn
    wait_for_device /dev/xen/gntdev
    wait_for_device /dev/xen/gntalloc
  '';
in
  with lib; {
    options.services.qubes.db.enable = mkEnableOption "the qubes db daemon";

    config = mkIf config.services.qubes.db.enable {
      boot.kernelModules = ["xen_evtchn" "xen_gntalloc" "xen_gntdev"];

      environment.systemPackages = [
        pkgs.qubes-core-qubesdb
      ];
      systemd.services.qubes-db = {
        description = "Qubes DB agent";
        wantedBy = ["sysinit.target"];
        after = ["systemd-modules-load.service"];

        unitConfig = {
          DefaultDependencies = false;
        };

        serviceConfig = {
          Group = "qubes";
          Restart = "on-failure";
          RestartSec = "1s";
          Type = "notify";
          ExecStartPre = "${init}/bin/qubes-db-init";
          ExecStart = "${pkgs.qubes-core-qubesdb}/bin/qubesdb-daemon 0";
        };
      };
    };
  }
