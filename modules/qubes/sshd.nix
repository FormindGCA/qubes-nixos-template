{
  config,
  lib,
  pkgs,
  ...
}: let
  sshd = pkgs.writeTextFile {
    name = "qubes-rpc-sshd";
    text = ''
      #!${pkgs.stdenv.shell}
      ${pkgs.socat}/bin/socat STDIO TCP:localhost:22
    '';
    executable = true;
    destination = "/etc/qubes-rpc/qubes.Sshd";
  };
in
with lib; {
  options.services.qubes.sshd.enable = mkEnableOption "enable sshd over qrexec";

  config = mkIf config.services.qubes.sshd.enable {
    services.qubes.networking.enable = true;
    services.qubes.qrexec.enable = true;

    services.qubes.qrexec.packages = [sshd];
    services.openssh.enable = true;
  };
}
