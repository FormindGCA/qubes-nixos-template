{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.qubes.updates;
in
with lib; {
  options.services.qubes.updates = {
    check = mkEnableOption "enable updates check, can be resource intensive due to required nix build";
    configurationDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "Directory containing the NixOS flake used for Qubes update checks.";
    };
    flakeConfiguration = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "NixOS flake configuration name used for update checks. Defaults to the runtime hostname.";
    };
    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--update-input"
        "nixpkgs"
        "--update-input"
        "qubes-nixos-template"
      ];
      example = [
        "-I"
        "stuff=/home/alice/nixos-stuff"
        "--option"
        "extra-binary-caches"
        "http://my-cache.example.org/"
      ];
      description = ''
        Any additional flags passed to {command}`nixos-rebuild`, used for both the check and actual update.

        If you are using flakes and use a local repo you can add
        {command}`[ "--update-input" "nixpkgs" "--commit-lock-file" ]`
        to update nixpkgs.
      '';
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = [pkgs.git pkgs.openssh];
      description = ''
        Any additional packages which should be available in the path for {command}`nixos-rebuild`, used for both the check and actual update.
      '';
    };
  };
  config = mkMerge [
    (
      mkIf config.services.qubes.updates.check {
        systemd.timers.qubes-update-check = {
          wantedBy = ["timers.target"];
        };
      }
    )
    (
      let
        upgradesStatusNotify = pkgs.writeShellScriptBin "upgrades-status-notify" ''
          set -e

          export PATH=${lib.makeBinPath cfg.extraPackages}:$PATH

          if [ "$1" = "started-by-init" ]; then
              true "INFO: Started by systemd unit (timer.) Continuing..."
          else
              true "INFO: Not started by systemd unit (timer.) Probably started by package manager hook script."
              if test -e /run/qubes/persistent-full; then
                  true "INFO: Running inside Template and Standalone. Continuing..."
              else
                  true "INFO: Probably running inside App Qube. Stop."
                  exit 0
              fi
          fi

          tempdir=$(mktemp -d /tmp/tmp.nix-updateinfo.XXX)
          cleanup() {
              rm -rf "$tempdir"
          }
          trap cleanup EXIT

          cp -r ${lib.escapeShellArg cfg.configurationDirectory}/. "$tempdir"
          cd "$tempdir"
          ${
            if cfg.flakeConfiguration == null
            then ''flakeConfig="$(${pkgs.nettools}/bin/hostname)"''
            else ''flakeConfig=${lib.escapeShellArg cfg.flakeConfiguration}''
          }
          ${config.nix.package.out}/bin/nix build ".#nixosConfigurations.$flakeConfig.config.system.build.toplevel" ${toString cfg.flags} 1>&2
          nix_diff=$(${config.nix.package.out}/bin/nix store diff-closures /run/current-system ./result \
            | ${pkgs.gawk}/bin/awk '/[0-9] →|→ [0-9]/ && !/nixos/' || true)
          echo "$nix_diff" 1>&2
          if [ -z "$nix_diff" ]; then
            ${pkgs.qubes-core-qrexec}/lib/qubes/qrexec-client-vm dom0 qubes.NotifyUpdates /bin/sh -c 'echo 0'
          else
            ${pkgs.qubes-core-qrexec}/lib/qubes/qrexec-client-vm dom0 qubes.NotifyUpdates /bin/sh -c 'echo 1'
          fi
        '';

        getPackages = pkgs.writeShellScriptBin "qubes-nixos-get-packages" ''
          empty=$(${config.nix.package.out}/bin/nix build --impure --no-link --print-out-paths --expr '(with import <nixpkgs> { }; pkgs.runCommand "empty" { } "mkdir -p $out")')
          ${config.nix.package.out}/bin/nix store diff-closures "$empty" /run/current-system | ${pkgs.gawk}/bin/awk '/→ [0-9]/ && !/nixos/' |  ${pkgs.gnused}/bin/sed 's/\x1b\[[0-9;]*m//g'
        '';

        nixosRebuildWrapper = pkgs.writeShellScriptBin "qubes-nixos-rebuild" ''
          export PATH=${lib.makeBinPath cfg.extraPackages}:$PATH

          # in update-proxy-configs we might set proxy via an override
          export all_proxy=$(systemctl show nix-daemon -p Environment | grep -oP '(?<=all_proxy=)[^ ]*')

          ${
            if cfg.flakeConfiguration == null
            then ''flakeConfig="$(${pkgs.nettools}/bin/hostname)"''
            else ''flakeConfig=${lib.escapeShellArg cfg.flakeConfiguration}''
          }
          flakeTarget=${lib.escapeShellArg cfg.configurationDirectory}#$flakeConfig

          # by default switch to the new generation, updating the system
          if [ $# -eq 0 ]; then
            ${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch --flake "$flakeTarget" ${toString cfg.flags}
          else
            ${config.system.build.nixos-rebuild}/bin/nixos-rebuild "$@"
          fi
        '';

        vmexec = pkgs.writeTextFile {
          name = "qubes-rpc-vmexec";
          # NOTE: in order to perform updates, qubes `vmupdate` injects a python agent into the vm and then
          # executes it. the agent then calls our scripts to perform various actions.
          # we need to ensure the VMExec RPC has the correct PATH to find the dependencies and
          # our update scripts.
          text = ''
            #!${pkgs.stdenv.shell}

            export PATH=${lib.makeBinPath (with pkgs; [bash coreutils fakeroot gawk gnugrep gnused gnutar python3 systemd upgradesStatusNotify getPackages nixosRebuildWrapper])}:/run/current-system/sw/bin:$PATH

            case "$1" in
              -2Fusr-2Fbin-2Fpython3+-2Frun-2Fqubes--update-2Fagent-2Fentrypoint.py*)
                qubes-nixos-rebuild
                upgrades-status-notify
                exit 0
                ;;
            esac

            exec ${config.services.qubes.core.package.out}/bin/qubes-vmexec "$@"
          '';
          executable = true;
          destination = "/etc/qubes-rpc/qubes.VMExec";
        };
      in {
        systemd.tmpfiles.rules = [
          "d /usr/lib 0755 root root"
          "d /usr/lib/qubes 0755 root root"
          "L+ /usr/lib/qubes/upgrades-status-notify - - - - ${upgradesStatusNotify}/bin/upgrades-status-notify"
        ];
        environment.systemPackages = [
          nixosRebuildWrapper
        ];
        services.qubes.qrexec.packages = [vmexec];
        systemd.services.qubes-update-check = {
          serviceConfig = {
            ExecStart = ["" "${upgradesStatusNotify}/bin/upgrades-status-notify started-by-init"];
          };
        };
      }
    )
  ];
}
