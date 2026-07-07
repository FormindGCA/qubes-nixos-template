{
  lib,
  stdenv,
  socat,
  writeTextFile,
}:
writeTextFile {
  name = "qubes-rpc-sshd";
  text = ''
    #!${stdenv.shell}
    ${socat}/bin/socat STDIO TCP:localhost:22
  '';
  executable = true;
  destination = "/etc/qubes-rpc/qubes.Sshd";
} // {
  meta = with lib; {
    description = "Qubes RPC action to proxy SSH connections to localhost:22 via qrexec";
    homepage = "https://qubes-os.org";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [];
  };
}
