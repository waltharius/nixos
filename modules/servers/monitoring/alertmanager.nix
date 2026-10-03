# modules/servers/monitoring/alertmanager.nix
#
# Alertmanager on the monitoring server: groups the alerts Prometheus sends
# and delivers them. Grafana shows its alerts and silences through the
# Alertmanager data source (grafana.nix). The web UI is open on the LAN
# interface (port 9093, no authentication: anyone in the LAN can create
# silences) so the "View In Alertmanager" link in alert e-mails works; the
# link is built from `webExternalUrl`, by default http://<host name>:9093.
# Phase B (BACKLOG.md) puts Caddy with TLS and authentication in front.
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
{
  config,
  host,
  ...
}: let
  mail = config.fleet.monitoring.mail;
  credential = "healthchecks-url";
in {
  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "0.0.0.0"; # firewall below: LAN interface only
    port = 9093;
    webExternalUrl = "http://${host.name}.${config.networking.domain}:${toString config.services.prometheus.alertmanager.port}";

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
        # One notification per alert ("..." = all labels), as Checkmk did:
        # a separate e-mail when it fires and when it is resolved, never a
        # group mixing both. Costs more mails when many alerts fire at once.
        group_by = ["..."];
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
              # "CRITICAL office-asus: Filesystem / is read-only" when it
              # fires, "RESOLVED office-asus: ..." when it ends: the host first
              # (it is what fits in a mail list), then the rule's summary
              # with its " on <host>" removed. No [brackets] around the status:
              # with "[CRITICAL] x" / "[RESOLVED] x" Proton Mail still put
              # firing and resolved into one conversation, apparently
              # ignoring a bracketed prefix (observed 2026-10-03). Rules
              # without a host label: status and summary. The body stays
              # Alertmanager's default HTML.
              headers.Subject = builtins.concatStringsSep "" [
                ''{{ if eq .Status "firing" }}{{ .CommonLabels.severity | toUpper }}{{ else }}RESOLVED{{ end }} ''
                ''{{ with .CommonLabels.host }}{{ . }}: {{ end }}''
                ''{{ with .CommonAnnotations.summary }}''
                ''{{ if $.CommonLabels.host }}{{ reReplaceAll (printf " on %s" $.CommonLabels.host) "" . }}{{ else }}{{ . }}{{ end }}''
                ''{{ else }}{{ $.CommonLabels.alertname }}{{ end }}''
              ];
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

  # Web UI from the LAN interface only, as for Grafana and Prometheus.
  networking.firewall.interfaces.${host.lan.interface}.allowedTCPPorts = [config.services.prometheus.alertmanager.port];

  sops.secrets.healthchecks-watchdog-url = {
    sopsFile = ../../../secrets/altair.yaml;
    # Key in secrets/altair.yaml: healthchecks-watchdog-url
    # Value: the check's ping URL, https://hc-ping.com/<uuid>
  };
}
