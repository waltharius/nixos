# modules/servers/monitoring/alertmanager.nix
#
# Alertmanager on the monitoring server: groups the alerts Prometheus sends
# and delivers them. Listens on loopback only; Grafana shows its alerts and
# silences through the Alertmanager data source (grafana.nix).
#
# Receivers:
#   email        - every alert, firing and resolved, through the local
#                  Postfix (mail.nix) to `monitoring.mail.to` in
#                  hosts/fleet.nix
#   healthchecks - only the always-firing Watchdog alert, as a webhook to
#                  healthchecks.io every 2 minutes. When the pings stop
#                  (monitoring server down, Alertmanager broken, no
#                  internet), healthchecks.io e-mails on its own. The ping
#                  URL is a secret: `healthchecks-watchdog-url` in
#                  secrets/altair.yaml, handed to the service as a systemd
#                  credential.
#
# Inhibition: while a host is down (HostDown), its other warnings and info
# alerts are not sent.
{config, ...}: let
  mail = config.fleet.monitoring.mail;
  credential = "healthchecks-url";
in {
  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9093;

    configuration = {
      global = {
        smtp_smarthost = "127.0.0.1:25";
        smtp_from = mail.from;
        smtp_hello = "localhost";
        # Postfix on loopback offers no TLS; it uses TLS outbound itself.
        smtp_require_tls = false;
        resolve_timeout = "5m";
      };

      route = {
        receiver = "email";
        group_by = ["alertname" "host"];
        group_wait = "30s";
        group_interval = "5m";
        # A still-firing alert is e-mailed again twice a day.
        repeat_interval = "12h";
        routes = [
          {
            matchers = [''alertname="Watchdog"''];
            receiver = "healthchecks";
            group_wait = "0s";
            group_interval = "1m";
            repeat_interval = "2m";
          }
        ];
      };

      receivers = [
        {
          name = "email";
          email_configs = [
            {
              to = mail.to;
              send_resolved = true;
            }
          ];
        }
        {
          name = "healthchecks";
          webhook_configs = [
            {
              url_file = "/run/credentials/alertmanager.service/${credential}";
              send_resolved = false;
            }
          ];
        }
      ];

      inhibit_rules = [
        {
          source_matchers = [''alertname="HostDown"''];
          target_matchers = [''severity=~"warning|info"''];
          equal = ["host"];
        }
      ];
    };
  };

  # The service runs with a dynamic user; systemd copies the secret into
  # its credentials directory, readable only by the service.
  systemd.services.alertmanager.serviceConfig.LoadCredential = [
    "${credential}:${config.sops.secrets.healthchecks-watchdog-url.path}"
  ];

  sops.secrets.healthchecks-watchdog-url = {
    sopsFile = ../../../secrets/altair.yaml;
    # Key in secrets/altair.yaml: healthchecks-watchdog-url
    # Value: the check's ping URL, https://hc-ping.com/<uuid>
  };
}
