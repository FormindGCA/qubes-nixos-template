{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.qubes.sshProxy;
  conditions = [
    "/run/qubes-service/ssh-proxy-setup"
    "!/run/qubes-service/qubes-ssh-proxy"
  ];
in {
  options.services.qubes.sshProxy = {
    enable = lib.mkEnableOption "SSH through a Qubes RPC proxy";
    target = lib.mkOption {
      type = lib.types.str;
      example = "sys-firewall-vpn";
      description = "Qube exposing the qubes.SshProxy RPC service.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8083;
      description = "Local HTTP CONNECT proxy port.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.qubes.qrexec.enable = true;
    environment.systemPackages = [pkgs.socat];

    systemd.sockets.qubes-nixos-ssh-proxy = {
      description = "Forward connections to the SSH proxy over Qubes RPC";
      wantedBy = ["multi-user.target"];
      unitConfig.ConditionPathExists = conditions;
      socketConfig = {
        ListenStream = "127.0.0.1:${toString cfg.port}";
        BindToDevice = "lo";
        Accept = true;
      };
    };

    systemd.services."qubes-nixos-ssh-proxy@" = {
      description = "Forward an SSH proxy connection over Qubes RPC";
      requires = ["qubes-nixos-ssh-proxy.socket" "qubes-qrexec-agent.service"];
      after = ["qubes-qrexec-agent.service"];
      unitConfig.ConditionPathExists = conditions;
      serviceConfig = {
        ExecStart = "${pkgs.qubes-core-qrexec}/lib/qubes/qrexec-client-vm ${lib.escapeShellArg cfg.target} qubes.SshProxy";
        StandardInput = "socket";
        StandardOutput = "socket";
        StandardError = "journal";
      };
    };
  };
}
