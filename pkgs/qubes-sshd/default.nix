{
  lib,
  stdenv,
  socat,
  writeTextFile,
}:
let
  qubesLib = import ../lib.nix {inherit lib;};
in
writeTextFile {
  name = "qubes-rpc-sshd";
  text = ''
    #!${stdenv.shell}
    ${socat}/bin/socat STDIO TCP:localhost:22
  '';
  executable = true;
  destination = "/etc/qubes-rpc/qubes.Sshd";
} // {
  meta = qubesLib.meta "Qubes RPC action to proxy SSH connections to localhost:22 via qrexec";
}
