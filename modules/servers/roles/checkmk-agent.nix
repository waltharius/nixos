# modules/servers/roles/checkmk-agent.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.server-role.checkmk-agent;
in {
  options.services.server-role.checkmk-agent = {
    enable = mkEnableOption "Check_MK monitoring agent";

    port = mkOption {
      type = types.port;
      default = 6556;
      description = "Check_MK agent port";
    };

    allowedIPs = mkOption {
      type = types.listOf types.str;
      default = ["192.168.50.0/24"];
      description = "IP ranges allowed to connect to agent";
    };
  };

  config = mkIf cfg.enable {
    # Install Check_MK agent package
    environment.systemPackages = with pkgs; [
      check-mk-agent
    ];

    # Xinetd service for Check_MK
    services.xinetd = {
      enable = true;
      services = [
        {
          name = "check_mk";
          port = cfg.port;
          unlisted = true;
          user = "root";
          server = "${pkgs.check-mk-agent}/bin/check_mk_agent";
          serverArgs = "";
          extraConfig = ''
            only_from = ${concatStringsSep " " cfg.allowedIPs}
            disable = no
          '';
        }
      ];
    };

    # Firewall rules - restrict to monitoring server
    networking.firewall.extraCommands = ''
      ${concatMapStringsSep "\n" (ip: ''
          iptables -A INPUT -s ${ip} -p tcp --dport ${toString cfg.port} -j ACCEPT
        '')
        cfg.allowedIPs}
    '';
  };
}
