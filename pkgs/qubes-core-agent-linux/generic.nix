{
  fetchFromGitHub,
  lib,
  resholve,
  makeWrapper,
  wrapGAppsNoGuiHook,
  bash,
  coreutils,
  diffutils,
  e2fsprogs,
  dconf,
  desktop-file-utils,
  fakeroot,
  findutils,
  gawk,
  getent,
  gnome-packagekit,
  gnugrep,
  gobject-introspection,
  graphicsmagick,
  haveged,
  iproute2,
  kmod,
  librsvg,
  libx11,
  lsb-release,
  lvm2,
  mount,
  nettools,
  ntp,
  pandoc,
  parted,
  pkg-config,
  procps,
  psmisc,
  python3,
  python3Packages,
  qubes-core-qrexec,
  qubes-core-qubesdb,
  qubes-core-vchan-xen,
  qubes-linux-utils,
  gnused,
  shared-mime-info,
  socat,
  systemd,
  umount,
  util-linux,
  xdg-utils,
  zenity,
  networkmanager,
  tinyproxy,
  nftables,
  conntrack-tools,
  enableNetworking ? false,
  version,
  hash,
  rev ? null,
}: let

  scripts_using_functions = [
    "lib/qubes/init/qubes-early-vm-config.sh"
    "lib/qubes/init/qubes-sysinit.sh"
    "lib/qubes/init/misc-post.sh"
    "lib/qubes/init/mount-dirs.sh"
    "lib/qubes/init/setup-rwdev.sh"
    "lib/qubes/init/bind-dirs.sh"
  ];

  scripts =
    scripts_using_functions
    ++ [
      "etc/qubes-rpc/qubes.Filecopy"
      "etc/qubes-rpc/qubes.VMShell"
      "etc/qubes-rpc/qubes.WaitForSession"
      "lib/qubes/init/functions"
      "lib/qubes/init/setup-rw.sh"
      "lib/qubes/init/resize-rootfs-if-needed.sh"
      "lib/qubes/resize-rootfs"
      "lib/qubes/update-proxy-configs"
      #"bin/qvm-open-in-dvm"
      #"bin/qvm-run-vm"
    ];

    src = fetchFromGitHub {
      owner = "QubesOS";
      repo = "qubes-core-agent-linux";
      rev = if rev != null then rev else "v${version}";
      inherit hash;
    };

    qubesagent = python3Packages.buildPythonPackage {
      pname = "qubesagent";
      inherit version src;
      format = "setuptools"; # default, can be omitted if using setuptools

  };

    pythonRuntimeDeps = with python3Packages; [
      dbus-python
      pygobject3
      pyxdg
    ] ++ [
      qubes-core-qubesdb
      qubesagent
    ];

    programPythonPath = python3Packages.makePythonPath pythonRuntimeDeps;

in
  resholve.mkDerivation rec {
    inherit version src;
    pname = "qubes-core-agent-linux";

    nativeBuildInputs =
      [
        bash
        desktop-file-utils
        gobject-introspection
        lsb-release
        pandoc
        pkg-config
        python3
        makeWrapper
        qubes-core-qubesdb
        qubes-core-vchan-xen
        qubes-linux-utils
        shared-mime-info
        wrapGAppsNoGuiHook
        libx11
      ]
      ++ (with python3Packages; [
        wrapPython
        distutils
        setuptools
      ]);

    buildInputs =
      [
        coreutils
        dconf
        fakeroot
        gawk
        gnome-packagekit
        gnused
        graphicsmagick
        haveged
        iproute2
        librsvg
        ntp
        parted
        procps
        python3
        qubes-core-qrexec
        qubes-core-vchan-xen
        qubes-core-qubesdb
        qubes-linux-utils
        socat
        xdg-utils
        zenity
      ]
      ++ lib.optional enableNetworking networkmanager
      ++ lib.optional enableNetworking tinyproxy
      ++ lib.optional enableNetworking nftables
      ++ lib.optional enableNetworking conntrack-tools
      ++ (with python3Packages; [
        dbus-python
        pygobject3
        pyxdg
      ]);

    postPatch = ''
      substituteInPlace Makefile --replace-fail 'SHELL = /bin/bash' 'SHELL = ${bash}/bin/bash'

      # skip installing qfile-unpacker / bin-qfile-unpacker as SUID
      substituteInPlace qubes-rpc/Makefile --replace-fail '-m 4755' '-m 755'
    '';

    buildPhase = ''
      for dir in qubes-rpc misc; do
          make -C "$dir"
      done
    '';

    # Don't move doc, needed in the subsequent packaging
    forceShare = ["man" "info"];

    installPhase =
      ''
        make install-corevm \
            PYTHON_PREFIX_ARG="--prefix ." \
            DESTDIR="$out" \
            BINDIR=/bin \
            SBINDIR=/bin \
            LIBDIR=/lib \
            SYSLIBDIR=/lib \
            SYSTEM_DROPIN_DIR=/usr/lib/systemd/system \
            USER_DROPIN_DIR=/usr/lib/systemd/user \
            DIST=nixos \
            PYTHON=${python3}/bin/python3
        make -C app-menu install DESTDIR="$out" install BINDIR=/bin LIBDIR=/lib
        make -C misc install DESTDIR="$out" LIBDIR=/lib SYSLIBDIR=/lib
        make -C qubes-rpc DESTDIR="$out" BINDIR=/bin LIBDIR=/lib install
        make -C qubes-rpc/caja DESTDIR="$out" BINDIR=/bin LIBDIR=/lib install
        make -C qubes-rpc/kde DESTDIR="$out" BINDIR=/bin LIBDIR=/lib install
        make -C qubes-rpc/nautilus DESTDIR="$out" BINDIR=/bin LIBDIR=/lib QUBESLIBDIR=/lib/qubes install
        make -C qubes-rpc/thunar DESTDIR="$out" BINDIR=/bin LIBDIR=/lib install

        # fixup symlinks, noBrokenSymlinks should only fail for symlinks pointing inside the store
        IFS=; while read -r i; do \
          case ''$i in \
            ('''|'#'*) continue;; \
            (*[!A-Za-z0-9._-]*) \
              printf 'ERROR: bad data directory "%s"\n' "''$i" >&2; exit 1;;\
          esac; \
          ln -sf "/run/current-system/sw/share/''$i" $out/usr/share/qubes/xdg-override; \
        done < misc/data-dirs
        rm $out/usr/share/applications/defaults.list

        # install cron bindmount
        mkdir -p "$out/lib/qubes-bind-dirs.d"
        install -m 0644 "filesystem/30_cron.conf" "$out/lib/qubes-bind-dirs.d/30_cron.conf"

        # nixos does not have /etc/skel, initialize_home() requires it
        substituteInPlace "$out/lib/qubes/init/functions" --replace-fail "/etc/skel" "/var/empty"

        # Fixup paths
        substituteInPlace "$out/bin/qubes-session-autostart" --replace-fail "QUBES_XDG_CONFIG_DROPINS = '/etc/qubes/autostart'" "QUBES_XDG_CONFIG_DROPINS = \"$out/etc/qubes/autostart\""

        substituteInPlace "$out/lib/qubes/qubes-trigger-sync-appmenus.sh" \
          --replace-fail '. /usr/lib/qubes/init/functions' ". $out/lib/qubes/init/functions" \
          --replace-fail '/usr/lib/qubes/qrexec-client-vm' "${qubes-core-qrexec}/lib/qubes/qrexec-client-vm"
        substituteInPlace "$out/etc/qubes/post-install.d/10-qubes-core-agent-appmenus.sh" \
          --replace-fail '/usr/lib/qubes/qubes-trigger-sync-appmenus.sh' "$out/lib/qubes/qubes-trigger-sync-appmenus.sh"

        # qvm-copy now uses $scriptdir relative paths; only qrexec-client-vm needs
        # explicit store path since it lives in qubes-core-qrexec, not here
        substituteInPlace "$out/bin/qvm-copy" --replace-fail '$scriptdir/qubes/qrexec-client-vm' "${qubes-core-qrexec}/lib/qubes/qrexec-client-vm"
        
        # patching qvm-open-in-dvm
        substituteInPlace "$out/bin/qvm-open-in-dvm" --replace-fail "/bin/sh -c" "${bash}/bin/sh -c"
        substituteInPlace "$out/bin/qvm-open-in-dvm" --replace-fail "/usr/lib/qubes/qopen-in-vm" "$out/lib/qubes/qopen-in-vm"
        substituteInPlace "$out/bin/qvm-open-in-dvm" --replace-fail "/usr/lib/qubes/qrexec-client-vm" "${qubes-core-qrexec}/lib/qubes/qrexec-client-vm"
        
        # patching qvm-run-vm
        substituteInPlace "$out/bin/qvm-run-vm" --replace-fail "/usr/lib/qubes/qrun-in-vm" "$out/lib/qubes/qrun-in-vm"
        substituteInPlace "$out/bin/qvm-run-vm" --replace-fail "/usr/lib/qubes/qrexec-client-vm" "${qubes-core-qrexec}/lib/qubes/qrexec-client-vm"

        # first instance is an absolute path check, we could also just hardcode this to true
        substituteInPlace "$out/bin/qvm-open-in-dvm" --replace-fail "/usr/bin/zenity" "${zenity}/bin/zenity"

        # use suid wrapper we will create in the module
        substituteInPlace "$out/etc/qubes-rpc/qubes.Filecopy" --replace-fail "/usr/lib/qubes/qfile-unpacker" "/run/wrappers/bin/qfile-unpacker"

        # Patch Python shebangs under etc/qubes-rpc for NixOS
        substituteInPlace "$out/etc/qubes-rpc/qubes.StartApp" --replace-fail '#!/usr/bin/python3' "#!${python3}/bin/python3"
        substituteInPlace "$out/etc/qubes-rpc/qubes.GetImageRGBA" \
          --replace-fail '/usr/lib/qubes/xdg-icon' "$out/lib/qubes/xdg-icon" \
          --replace-fail 'ICON_MAXSIZE=512' 'ICON_MAXSIZE=128'
        substituteInPlace "$out/lib/qubes/xdg-icon" \
          --replace-fail 'themes = themes + sorted([d for d in os.listdir("/usr/share/icons") if d not in themes and os.path.isdir("/usr/share/icons/" + d)])' \
          $'icon_dirs = []\nfor data_dir in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):\n    icons_dir = os.path.join(data_dir, "icons")\n    if os.path.isdir(icons_dir):\n        icon_dirs.append(icons_dir)\nthemes = themes + sorted({d for icons_dir in icon_dirs for d in os.listdir(icons_dir) if d not in themes and os.path.isdir(os.path.join(icons_dir, d))})'
        substituteInPlace "$out/lib/${python3.libPrefix}/site-packages/qubesagent/vmexec.py" \
          --replace-fail '    os.execvp(command[0], command)' \
          $'    if command[0] == b\'/usr/bin/python3\':\n        command[0] = b\'${python3}/bin/python3\'\n    elif command[0].endswith(b\'.py\'):\n        command = [b\'${python3}/bin/python3\'] + command\n    try:\n        os.execvp(command[0], command)\n    except FileNotFoundError:\n        print(\'VMExec command not found: {}\'.format([part.decode(\'utf-8\', \'replace\') for part in command]), file=sys.stderr)\n        raise'

        for path in ${lib.concatStringsSep " " scripts_using_functions}; do
          substituteInPlace "$out/$path" --replace-fail '/usr/lib/qubes/init/functions' "functions"
        done

        substituteInPlace "$out/lib/qubes/init/bind-dirs.sh" --replace-fail \
          'sources=( "/usr/lib/qubes-bind-dirs.d" "/etc/qubes-bind-dirs.d" )' \
          "sources=( \"$out/lib/qubes-bind-dirs.d\" )"

        substituteInPlace "$out/lib/qubes/init/resize-rootfs-if-needed.sh" \
          --replace-fail '/usr/lib/qubes/resize-rootfs' 'resize-rootfs'

        # remove the default VMExec definition since we need to modify it's PATH based on user args in the updates module
        rm "$out/etc/qubes-rpc/qubes.VMExec"
        # also remove VMExecGUI since it points to VMExec and will be a dangling link
        rm "$out/etc/qubes-rpc/qubes.VMExecGUI"

        mv "$out/usr/bin/qubes-vmexec" "$out/bin/"
        mv "$out/usr/share" "$out/share"
        mv "$out/etc/systemd/system/xendriverdomain.service" "$out/lib/systemd/system/"

        rm -rf "$out/usr/bin"
        rm -rf "$out/var/run"
      ''
      + lib.optionalString (!enableNetworking) ''
        # mock update-proxy-configs with an empty script
        echo "#!${bash}/bin/sh" > "$out/lib/qubes/update-proxy-configs"
        chmod +x "$out/lib/qubes/update-proxy-configs"
      ''
      + lib.optionalString enableNetworking ''
        make -C network install \
            PYTHON_PREFIX_ARG="--prefix ." \
            DESTDIR="$out" \
            BINDIR=/bin \
            SBINDIR=/bin \
            LIBDIR=/lib \
            SYSLIBDIR=/lib \
            SYSTEM_DROPIN_DIR=/usr/lib/systemd/system \
            USER_DROPIN_DIR=/usr/lib/systemd/user \
            DIST=nixos
        make install-netvm \
            PYTHON_PREFIX_ARG="--prefix ." \
            DESTDIR="$out" \
            BINDIR=/bin \
            SBINDIR=/bin \
            LIBDIR=/lib \
            SYSLIBDIR=/lib \
            SYSTEM_DROPIN_DIR=/usr/lib/systemd/system \
            USER_DROPIN_DIR=/usr/lib/systemd/user \
            DIST=nixos

        # overwrite the broken symlink created by make install-netvm
        ln -sf ../../lib/qubes/qubes-setup-dnat-to-ns $out/etc/dhclient.d/qubes-setup-dnat-to-ns.sh

        for path in lib/qubes/init/network-uplink-wait.sh lib/qubes/setup-ip lib/qubes/update-proxy-configs ; do
          substituteInPlace "$out/$path" --replace-fail '/usr/lib/qubes/init/functions' "functions"
        done

        cat >> "$out/lib/qubes/update-proxy-configs" <<EOT

        # NixOS
        if [ -d /run/current-system ]; then
            # setup for anything using nix-daemon
            mkdir -p /run/systemd/system/nix-daemon.service.d
            cat > /run/systemd/system/nix-daemon.service.d/override.conf <<EOF
        # This file is automatically generated by Qubes (\$0 script).
        # All modifications here will be lost.
        [Service]
        Environment="all_proxy=\$PROXY_ADDR"
        EOF

            # also setup the proxy for our updates check explicitly since some downloads
            # (e.g. flake updates) do not go through the nix daemon
            mkdir -p /run/systemd/system/qubes-update-check.service.d
            cp /run/systemd/system/nix-daemon.service.d/override.conf /run/systemd/system/qubes-update-check.service.d/override.conf

            systemctl daemon-reload
            systemctl restart nix-daemon
        fi
        EOT

        substituteInPlace "$out/etc/udev/rules.d/99-qubes-network.rules" --replace-fail '/usr/bin/systemctl' '${systemd}/bin/systemctl'

        mv "$out/etc/udev/rules.d/99-qubes-network.rules" "$out/lib/udev/rules.d/"
      '';

    solutions = {
      default = {
        scripts =
          scripts
          ++ lib.optional enableNetworking "lib/qubes/init/network-uplink-wait.sh"
          ++ lib.optional enableNetworking "lib/qubes/setup-ip";
        interpreter = "none";
        fake = {
          external =
            # guarded by check for /sys/fs/selinux
            ["chcon" "restorecon"]
            # guarded by check for
            # called by misc-post.sh (at runtime, from glibc)
            ++ ["ldconfig"]
            ++ ["kdialog"]
            ++ lib.optional (!enableNetworking) "ip";
        };
        fix = {
          "/bin/bash" = true;
          "/usr/bin/qubes-vmexec" = true;
          "/usr/bin/qubesdb-read" = true;
          "/usr/lib/qubes/init/bind-dirs.sh" = true;
          "/usr/lib/qubes/init/setup-rw.sh" = true;
          "/usr/lib/qubes/init/setup-rwdev.sh" = true;
          "/usr/lib/qubes/qrexec-client-vm" = true;
          "/usr/lib/qubes/qubes-fs-tree-check" = true;
          "/usr/lib/qubes/qubes-setup-dnat-to-ns" = true;
          "/usr/lib/qubes/qvm_nautilus_bookmark.sh" = true;
          "/usr/lib/qubes/update-proxy-configs" = true;
          "/lib/systemd/systemd-sysctl" = true;
          "/sbin/ip" = true;
          umount = true;
          mount = true;
        };
        inputs =
          [
            "bin"
            "lib/qubes"
            "lib/qubes/init"
            "${qubes-core-qrexec}/lib/qubes"
            "${systemd}/lib/systemd"
            bash
            coreutils
            diffutils
            e2fsprogs
            findutils
            gawk
            getent
            gnugrep
            gnused
            kmod
            lvm2
            mount
            nettools
            parted
            procps
            psmisc
            qubes-core-qrexec
            qubes-core-qubesdb
            systemd
            umount
            util-linux
            zenity
          ]
          ++ lib.optionals enableNetworking [networkmanager iproute2];
        keep = {
          source = ["$file_name"];
          "$rc" = true;
          "/rw/config/qubes_ip_change_hook" = enableNetworking;
          "/rw/config/qubes-ip-change-hook" = enableNetworking;
          "/run/wrappers/bin/qfile-unpacker" = true;

          # allow the dynamic commands used in mount-dirs.sh
          "$mount_home" = true;
          "$mount_usr_local" = true;
        };
        execer =
          [
            "cannot:${e2fsprogs}/bin/fsck.ext4"
            "cannot:${e2fsprogs}/bin/mkfs.ext4"
            "cannot:${kmod}/bin/modprobe"
            "cannot:${lib.getBin lvm2}/bin/dmsetup"
            "cannot:${systemd}/bin/systemctl"
            "cannot:${systemd}/bin/udevadm"
            "cannot:bin/qubes-vmexec"
            "cannot:lib/qubes/init/bind-dirs.sh"
            "cannot:lib/qubes/qfile-unpacker"
            "cannot:${qubes-core-qrexec}/lib/qubes/qrexec-client-vm"
            "cannot:${zenity}/bin/zenity"
          ]
          ++ lib.optionals enableNetworking ["cannot:${networkmanager}/bin/nmcli" "cannot:${iproute2}/bin/ip"];
      };
    };

    pythonPath = pythonRuntimeDeps;

    dontWrapGApps = true;

    preFixup = ''
      makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
      buildPythonPath "$out $pythonPath"
    '';

    postFixup = ''
      wrapPythonPrograms

      program_PYTHONPATH="$out/${python3.sitePackages}:${programPythonPath}:${qubes-core-qubesdb}/${python3.sitePackages}"
      program_LIBRARY_PATH="${qubes-core-qubesdb}/lib:${qubes-core-vchan-xen}/lib"

      # These are not normal Python entry points, so wrapPythonPrograms does not
      # reliably discover every import path they need.
      wrapProgram "$out/etc/qubes-rpc/qubes.StartApp" \
        --set PYTHONPATH "$program_PYTHONPATH" \
        --prefix LD_LIBRARY_PATH : "$program_LIBRARY_PATH" \
        --prefix PATH : "/run/wrappers/bin:/home/user/.nix-profile/bin:/nix/profile/bin:/home/user/.local/state/nix/profile/bin:/etc/profiles/per-user/user/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin" \
        --prefix XDG_DATA_DIRS : "/run/current-system/sw/share:/etc/profiles/per-user/user/share:/home/user/.nix-profile/share"
      wrapProgram "$out/etc/qubes-rpc/qubes.GetAppmenus" \
        --prefix PATH : "$out/bin:${coreutils}/bin:${findutils}/bin:${gawk}/bin:${qubes-core-qubesdb}/bin:/run/current-system/sw/bin"
      wrapProgram "$out/etc/qubes-rpc/qubes.GetImageRGBA" \
        --prefix PATH : "${coreutils}/bin:${graphicsmagick}/bin:${librsvg}/bin"
      wrapProgram "$out/lib/qubes/xdg-icon" \
        --set PYTHONPATH "$program_PYTHONPATH" \
        --prefix XDG_DATA_DIRS : "/run/current-system/sw/share:/etc/profiles/per-user/user/share:/home/user/.nix-profile/share"
      wrapProgram "$out/bin/qubes-vmexec" \
        --set PYTHONPATH "$program_PYTHONPATH" \
        --prefix LD_LIBRARY_PATH : "$program_LIBRARY_PATH"
    '';

    meta = with lib; {
      description = "The Qubes core files for installation inside a Qubes VM";
      homepage = "https://qubes-os.org";
      license = licenses.gpl2Plus;
      maintainers = [];
      platforms = platforms.linux;
    };
  }
