{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.qubes.gpgSplit;
in {
  options.services.qubes.gpgSplit = {
    enable = lib.mkEnableOption "Qubes Split GPG client";
    server = lib.mkEnableOption "the Qubes Split GPG key-holder services";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.qubes.qrexec.enable = true;
      environment.systemPackages = [pkgs.qubes-gpg-split];
      environment.etc."profile.d/qubes-gpg.sh".source = "${pkgs.qubes-gpg-split}/etc/profile.d/qubes-gpg.sh";
    }
    (lib.mkIf cfg.server {
      services.qubes.qrexec.packages = [pkgs.qubes-gpg-split];
      systemd.tmpfiles.rules = ["d /run/qubes-gpg-split 0775 root qubes"];
    })
  ]);
}
