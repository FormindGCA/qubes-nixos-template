{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.qubes.core;
in
  with lib; {
    options.services.qubes.core = {
      enable = mkEnableOption "the core qubes services";
      user = {
        name = mkOption {
          type = types.str;
          default = "user";
          description = "Default user created for the Qubes template VM.";
        };
        uid = mkOption {
          type = types.int;
          default = 1000;
          description = "UID of the default Qubes user.";
        };
        gid = mkOption {
          type = types.int;
          default = 1000;
          description = "GID of the default Qubes user group.";
        };
        home = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Home directory for the default Qubes user. Defaults to /home/<name>.";
        };
        autologin = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to autologin the default Qubes user on getty.";
        };
      };
      package = mkOption {
        type = types.package;
        description = "qubes-core-agent-linux package used by core services.";
        internal = true;
        defaultText = literalExpression "pkgs.qubes-core-agent-linux";
        default = pkgs.qubes-core-agent-linux;
      };
      basePackage = mkOption {
        type = types.package;
        description = "Base qubes-core-agent-linux package used for generic core services and qrexec RPCs.";
        defaultText = literalExpression "pkgs.qubes-core-agent-linux";
        default = pkgs.qubes-core-agent-linux;
      };
      networkingPackage = mkOption {
        type = types.package;
        description = "Networking-enabled qubes-core-agent-linux package used only by Qubes networking services.";
        defaultText = literalExpression ''pkgs.qubes-core-agent-linux.override { enableNetworking = true; }'';
        default = pkgs.qubes-core-agent-linux.override {enableNetworking = true;};
      };
    };
    config = mkIf cfg.enable (
      let
        qubes-core-agent-linux = cfg.basePackage;
        userHome =
          if cfg.user.home != null
          then cfg.user.home
          else "/home/${cfg.user.name}";
      in mkMerge [
        {
        services.qubes.core.package = qubes-core-agent-linux;
        services.qubes.db.enable = true;

        boot.initrd.kernelModules = ["xen_blkfront" "dm_mod" "dm_snapshot"];
        boot.kernelModules = ["xenfs"];

        # Keep xenfs out of fstab/local-fs.target.  It is mounted as a Qubes
        # service dependency instead, so failure blocks Qubes services without
        # dropping the whole VM into emergency mode.
        fileSystems."/proc/xen".enable = mkForce false;
        systemd.suppressedSystemUnits = ["proc-xen.mount"];

        boot.initrd.services.udev.rules = ''
          SUBSYSTEM=="block", KERNEL=="xvda3", SYMLINK+="mapper/dmroot", ENV{SYSTEMD_ALIAS}+="/dev/mapper/dmroot"
        '';

        boot.initrd.systemd.services.qubes-dmroot = mkIf config.boot.initrd.systemd.enable {
          description = "Create Qubes root device-mapper target";
          wantedBy = ["initrd-root-device.target"];
          before = ["initrd-root-device.target" "sysroot.mount"];
          after = ["systemd-modules-load.service" "systemd-udev-trigger.service"];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [
            pkgs.coreutils
            pkgs.lvm2
            pkgs.systemd
          ];
          script = ''
            set -eu

            wait_for_block() {
              local dev="$1"
              local i=0
              while [ ! -b "$dev" ]; do
                if [ "$i" -ge 50 ]; then
                  echo "$dev not found" >&2
                  exit 1
                fi
                sleep 0.1
                i=$((i + 1))
              done
            }

            udevadm settle || true
            wait_for_block /dev/xvda

            if [ -b /dev/mapper/dmroot ]; then
              exit 0
            fi

            mkdir -p /dev/mapper
            if [ -b /dev/xvda3 ]; then
              ln -s ../xvda3 /dev/mapper/dmroot
            elif [ "$(cat /sys/block/xvda/ro)" -eq 1 ]; then
              wait_for_block /dev/xvdc2
              xvda_size=$(cat /sys/block/xvda/size)
              table="0 $xvda_size snapshot /dev/xvda /dev/xvdc2 N 16"
              dmsetup create dmroot --table "$table"
            else
              xvda_size=$(cat /sys/block/xvda/size)
              table="0 $xvda_size linear /dev/xvda 0"
              dmsetup create dmroot --table "$table"
            fi

            udevadm settle || true
            wait_for_block /dev/mapper/dmroot
          '';
        };

        users.groups = {
          qubes = {
            # supposedly this should be 98, however 995 matches the debian value
            gid = 995;
          };
          ${cfg.user.name} = {
            gid = cfg.user.gid;
          };
        };
        users.users.${cfg.user.name} = {
          createHome = true;
          group = cfg.user.name;
          extraGroups = ["qubes" "wheel"];
          home = userHome;
          isNormalUser = true;
          password = "";
          shell = pkgs.bash;
          uid = cfg.user.uid;
        };
        security.sudo.wheelNeedsPassword = false;
        security.pam.services.su.text = lib.mkDefault (lib.mkBefore ''
          auth sufficient ${pkgs.linux-pam}/lib/security/pam_succeed_if.so use_uid user ingroup qubes
        '');

        fileSystems = {
          "/" = {
            device = "/dev/mapper/dmroot";
            fsType = "ext4";
          };
          "/rw" = {
            device = "/dev/xvdb";
            fsType = "auto";
            options = [
              "noauto"
              "defaults"
              "discard"
              "nosuid"
              "nodev"
            ];
          };
          "/home" = {
            depends = ["/rw"];
            device = "/rw/home";
            fsType = "none";
            options = [
              "noauto"
              "bind"
              "defaults"
              "nosuid"
              "nodev"
            ];
          };
          "/usr/local" = {
            depends = ["/rw"];
            device = "/rw/usrlocal";
            fsType = "none";
            options = [
              "noauto"
              "bind"
              "defaults"
            ];
          };
        };
        systemd.tmpfiles.rules = [
          # create mount point
          "d /rw 0755 root root"
          # Qubes tools use /usr/share in a few places, including StartApp's
          # app-dispvm override path.
          "d /usr 0755 root root"
          "L+ /usr/share - - - - /run/current-system/sw/share"
          # create mount point
          "d /usr/local 0755 root root"
          # mkdir so that first-boot-completed can be created here
          "d /var/lib/qubes 0755 root root"
        ];
        swapDevices = [
          {
            device = "/dev/xvdc1";
          }
        ];

        # qfile-unpacker needs setuid otherwise it fails during initgroups
        security.wrappers.qfile-unpacker = {
          owner = "root";
          group = "root";
          source = "${qubes-core-agent-linux}/bin/qfile-unpacker";
          setuid = true;
        };

        # adding to system packages will cause their xdg autostart files to be picked up
        environment.systemPackages = [
          qubes-core-agent-linux
        ];
        environment.etc."qubes".source = "${qubes-core-agent-linux}/etc/qubes";
        services.udev.packages = [
          pkgs.qubes-linux-utils
          qubes-core-agent-linux
        ];
        systemd.packages = [
          pkgs.qubes-linux-utils
          qubes-core-agent-linux
        ];

        # on other distros this is added on install of the package,
        # rather than create another module we just include in core
        systemd.services.qubes-meminfo-writer = {
          # ensure the service is started on boot, since Install is ignored
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            ExecStart = ["" "${pkgs.qubes-linux-utils}/bin/meminfo-writer 30000 100000 /run/meminfo-writer.pid"];
          };
        };

        systemd.services.qubes-proc-xen = {
          description = "Mount Xen control filesystem";
          before = ["qubes-db.service"];
          after = ["systemd-modules-load.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [
            pkgs.coreutils
            pkgs.kmod
          ];
          script = ''
            mkdir -p /proc/xen
            modprobe xenfs
            mountpoint -q /proc/xen || mount -t xenfs xenfs /proc/xen
          '';
        };

        systemd.services.qubes-db = {
          after = ["qubes-proc-xen.service"];
          requires = ["qubes-proc-xen.service"];
        };

        systemd.services.qubes-early-vm-config = {
          # ensure the service is started on boot, since Install is ignored
          wantedBy = ["sysinit.target"];

          serviceConfig = {
            ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/qubes-early-vm-config.sh"];
          };
        };

        systemd.services.qubes-misc-post = {
          # ensure the service is started on boot, since Install is ignored
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/misc-post.sh"];
            ExecStop = ["" "${qubes-core-agent-linux}/lib/qubes/init/misc-post-stop.sh"];
          };
        };

        systemd.services.qubes-mount-dirs = {
          # ensure the service is started on boot, since Install is ignored
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/mount-dirs.sh"];
          };
        };

        systemd.services.qubes-rootfs-resize = {
          wantedBy = ["multi-user.target"];
          after = ["qubes-sysinit.service"];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutSec = 10;
            ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/resize-rootfs-if-needed.sh"];
          };
        };

        systemd.services.qubes-sysinit = {
          # ensure the service is started on boot, since Install is ignored
          wantedBy = ["sysinit.target"];

          serviceConfig = {
            ExecStart = ["" "${qubes-core-agent-linux}/lib/qubes/init/qubes-sysinit.sh"];
          };
        };

        systemd.sockets."qubes-updates-proxy-forwarder" = {
          # ensure the socket is activated, since Install is ignored
          wantedBy = ["multi-user.target"];
        };

        systemd.services."qubes-updates-proxy-forwarder@" = {
          serviceConfig = {
            ExecStart = ["" "${pkgs.qubes-core-qrexec}/bin/qrexec-client-vm --use-stdin-socket '' qubes.UpdatesProxy"];
          };
        };

        systemd.services.xendriverdomain = {
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/log/xen";
            # Note: the first "" overrides the ExecStart from the upstream unit
            ExecStart = ["" "${pkgs.xen}/bin/xl devd"];
          };
        };

        # since there is no global nix proxy setting, add aliases which will
        # inherit the proxy settings from nix-daemon set by update-proxy-configs
        environment.interactiveShellInit = ''
          alias nix="all_proxy=\$(systemctl show nix-daemon -p Environment | grep -oP '(?<=all_proxy=)[^ ]*') nix"
          alias nix-shell="all_proxy=\$(systemctl show nix-daemon -p Environment | grep -oP '(?<=all_proxy=)[^ ]*') nix-shell"
          alias nixos-rebuild="all_proxy=\$(systemctl show nix-daemon -p Environment | grep -oP '(?<=all_proxy=)[^ ]*') nixos-rebuild"
        '';
      }
      (mkIf cfg.user.autologin {
        # ensure qvm-console-dispvm is logged in
        services.getty.autologinUser = cfg.user.name;
      })
      ]
    );
  }
