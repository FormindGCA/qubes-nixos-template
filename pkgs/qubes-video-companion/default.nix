{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  wrapGAppsNoGuiHook,
  pandoc,
  python3,
  coreutils,
  gnugrep,
  gobject-introspection,
  gst_all_1,
  gtk3,
  libayatana-appindicator,
  libnotify,
  kmod,
  qubes-core-qrexec,
  qubes-core-qubesdb,
  qubes-core-vchan-xen,
  systemd,
  util-linux,
  v4l-utils,
}: let
  qubesLib = import ../lib.nix {inherit lib fetchFromGitHub;};
  python = python3.withPackages (ps: [ps.pygobject3]);
  inherit (gst_all_1) gstreamer gst-plugins-base gst-plugins-good;
  gstPluginPath = lib.makeSearchPath "lib/gstreamer-1.0" [(lib.getLib gstreamer) gst-plugins-base gst-plugins-good];
  pythonEnv = ''
    --set PYTHONPATH "${qubes-core-qubesdb}/${python3.sitePackages}" \
    --prefix LD_LIBRARY_PATH : "${qubes-core-qubesdb}/lib:${qubes-core-vchan-xen}/lib" \
    --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH" \
    --set GST_PLUGIN_SYSTEM_PATH_1_0 "${gstPluginPath}" \
    --prefix PATH : "${coreutils}/bin"
  '';
in
  stdenv.mkDerivation rec {
    pname = "qubes-video-companion";
    version = "4.3.5-1";

    src = qubesLib.fetchFromQubes {
      repo = pname;
      inherit version;
  hash = "sha256-KHOryKNTi2jsRAdHb1WXAhJPdrjAJ2QGgE0wKQw4h+A=";
    };

    nativeBuildInputs = [makeWrapper pandoc python wrapGAppsNoGuiHook];
    buildInputs = [
      gobject-introspection
      gstreamer
      gst-plugins-base
      gst-plugins-good
      gtk3
      libayatana-appindicator
      libnotify
    ];
    dontWrapGApps = true;

    buildPhase = "make build";

    installPhase = ''
      make install-vm install-license \
        DESTDIR="$out" \
        BINDIR=/bin \
        DATADIR=/share \
        APPLICATIONSDIR=/share/applications \
        UDEVDIR=/lib/udev/rules.d

      mv "$out/usr/lib/systemd" "$out/lib/systemd"
      mv "$out/usr/lib/udev/rules.d/80-qubes-video-companion.rules" "$out/lib/udev/rules.d/"
      rm -rf "$out/usr" "$out/etc/sudoers.d" "$out/etc/privleap" "$out/etc/dkms"

      substituteInPlace "$out/bin/qubes-video-companion" \
        --replace-fail /usr/share/qubes-video-companion "$out/share/qubes-video-companion" \
        --replace-fail qrexec-client-vm "${qubes-core-qrexec}/bin/qrexec-client-vm" \
        --replace-fail 'opts=$(getopt ' 'opts=$(${util-linux}/bin/getopt ' \
        --replace-fail 'set -u -e' $'set -u -e\nexport GST_PLUGIN_SYSTEM_PATH_1_0=${gstPluginPath}'
      substituteInPlace "$out/share/qubes-video-companion/receiver/receiver.py" \
        --replace-fail /usr/bin/gst-launch-1.0 "${gstreamer}/bin/gst-launch-1.0"
      substituteInPlace "$out/share/qubes-video-companion/receiver/destroy.py" \
        --replace-fail '["notify-send"' '["${libnotify}/bin/notify-send"'
      substituteInPlace "$out/share/qubes-video-companion/receiver/setup.py" \
        --replace-fail '"sudo"' '"/run/wrappers/bin/sudo"' \
        --replace-fail '"modprobe"' '"${kmod}/bin/modprobe"' \
        --replace-fail '"udevadm"' '"${systemd}/bin/udevadm"'
      substituteInPlace "$out/share/qubes-video-companion/sender/webcam.py" \
        --replace-fail 'env={"PATH": "/bin:/usr/bin", "LC_ALL": "C"}' \
        'env={"PATH": "${v4l-utils}/bin", "LC_ALL": "C"}'
      substituteInPlace "$out/share/qubes-video-companion/sender/webcam_formats.py" \
        --replace-fail '["v4l2-ctl"' '["${v4l-utils}/bin/v4l2-ctl"'
      substituteInPlace "$out/share/qubes-video-companion/sender/udev-handler" \
        --replace-fail 'python3 /usr/share/qubes-video-companion' \
        '${python}/bin/python3 $out/share/qubes-video-companion'
      substituteInPlace "$out/lib/udev/rules.d/80-qubes-video-companion-sender.rules" \
        --replace-fail /usr/share/qubes-video-companion "$out/share/qubes-video-companion"
      substituteInPlace "$out/lib/systemd/system/qubes-video-companion-webcam@.service" \
        --replace-fail /usr/bin/qubes-video-companion "$out/bin/qubes-video-companion"
      substituteInPlace "$out/share/applications/qubes-video-companion-webcam.desktop" \
        "$out/share/applications/qubes-video-companion-screenshare.desktop" \
        --replace-fail /usr/bin/qubes-video-companion "$out/bin/qubes-video-companion"

      for service in qvc.Webcam qvc.ScreenShare; do
        substituteInPlace "$out/etc/qubes-rpc/$service" \
          --replace-fail /usr/bin/python3 "${python}/bin/python3" \
          --replace-fail /usr/share/qubes-video-companion "$out/share/qubes-video-companion"
        wrapProgram "$out/etc/qubes-rpc/$service" "''${gappsWrapperArgs[@]}" ${pythonEnv}
      done
      wrapProgram "$out/etc/qubes-rpc/qvc.WebcamAttach" \
        --prefix PATH : "${systemd}/bin:${coreutils}/bin:${gnugrep}/bin"
      wrapProgram "$out/etc/qubes-rpc/qvc.WebcamDetach" \
        --prefix PATH : "${coreutils}/bin:${gnugrep}/bin"
      wrapProgram "$out/share/qubes-video-companion/sender/udev-handler" \
        "''${gappsWrapperArgs[@]}" \
        --prefix PATH : "${coreutils}/bin:${qubes-core-qubesdb}/bin" \
        ${pythonEnv}
      patchShebangs "$out"

      GI_TYPELIB_PATH="$GI_TYPELIB_PATH" GST_PLUGIN_SYSTEM_PATH_1_0=${gstPluginPath} \
        ${python}/bin/python3 -c '
      import gi
      gi.require_version("Gst", "1.0")
      from gi.repository import Gst
      Gst.init()
      assert all(Gst.ElementFactory.find(element) for element in
        ("queue", "ximagesrc", "videoconvert", "fdsink", "fdsrc", "rawvideoparse", "v4l2sink"))
      '
    '';

    meta = qubesLib.meta "Securely stream webcams and share screens across Qubes VMs";
  }
