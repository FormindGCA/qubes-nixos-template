{
  lib,
  pkgs,
  ...
}: let
  cacheTarget = "nix-cache";
  cachePort = 5000;
  # Replace this after generating the cache key, then rebuild the TemplateVM.
  cachePublicKey = "qubes-nix-cache-1:REPLACE_WITH_THE_CACHE_PUBLIC_KEY";
  qrexecCacheClient = pkgs.writeShellScript "qrexec-nix-cache-client" ''
    exec ${pkgs.qubes-core-qrexec}/bin/qrexec-client-vm ${lib.escapeShellArg cacheTarget} qubes.NixCache
  '';
  qrexecCacheProxy = pkgs.writeShellScript "qrexec-nix-cache-proxy" ''
    exec ${pkgs.socat}/bin/socat \
      TCP-LISTEN:${toString cachePort},bind=127.0.0.1,reuseaddr,fork \
      EXEC:${qrexecCacheClient}
  '';
in {
  nix.settings = {
    substituters = lib.mkBefore ["http://127.0.0.1:${toString cachePort}"];
    trusted-public-keys = [cachePublicKey];
  };

  systemd.services.qubes-nix-cache-proxy = {
    description = "Qrexec proxy for the Nix binary cache";
    wantedBy = ["multi-user.target"];
    after = ["qubes-qrexec-agent.service"];
    requires = ["qubes-qrexec-agent.service"];

    serviceConfig = {
      ExecStart = qrexecCacheProxy;
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
