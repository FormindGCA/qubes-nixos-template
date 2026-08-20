{
  pkgs,
  ...
}: let
  cachePort = 5000;
  cacheSecretKey = "/var/lib/nix-cache/cache-secret-key.pem";
  qrexecCacheService = pkgs.writeTextFile {
    name = "qubes-rpc-nix-cache";
    destination = "/etc/qubes-rpc/qubes.NixCache";
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      exec ${pkgs.socat}/bin/socat STDIO TCP:127.0.0.1:${toString cachePort}
    '';
  };
in {
  services.nix-serve = {
    enable = true;
    bindAddress = "127.0.0.1";
    port = cachePort;
    secretKeyFile = cacheSecretKey;
  };

  services.qubes.qrexec.packages = [qrexecCacheService];

  systemd.tmpfiles.rules = [
    "d /var/lib/nix-cache 0700 root root"
    "d /var/lib/nix-cache/roots 0755 root root"
  ];

  systemd.services.nix-serve = {
    unitConfig.ConditionPathExists = cacheSecretKey;
    serviceConfig = {
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  environment.systemPackages = [pkgs.git];
}
