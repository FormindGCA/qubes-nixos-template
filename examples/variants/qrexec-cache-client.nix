{
  lib,
  pkgs,
  ...
}: let
  cacheTarget = "nix-cache";
  cachePort = 5000;
  # Replace this after generating the cache key, then rebuild the TemplateVM.
  cachePublicKey = "qubes-nix-cache-1:REPLACE_WITH_THE_CACHE_PUBLIC_KEY";
in {
  nix.settings = {
    substituters = lib.mkBefore ["http://127.0.0.1:${toString cachePort}"];
    trusted-public-keys = [cachePublicKey];
  };

  systemd.sockets.qubes-nix-cache-proxy = {
    description = "Qrexec proxy for the Nix binary cache";
    wantedBy = ["multi-user.target"];
    socketConfig.ListenStream = "127.0.0.1:${toString cachePort}";
    socketConfig.Accept = true;
  };

  systemd.services."qubes-nix-cache-proxy@" = {
    description = "Forward a Nix cache connection over Qubes RPC";
    after = ["qubes-qrexec-agent.service"];
    requires = ["qubes-qrexec-agent.service"];

    serviceConfig = {
      ExecStart = "${pkgs.qubes-core-qrexec}/bin/qrexec-client-vm ${lib.escapeShellArg cacheTarget} qubes.NixCache";
      StandardInput = "socket";
      StandardOutput = "socket";
    };
  };
}
