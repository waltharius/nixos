# modules/servers/monitoring/blackbox.nix
#
# Blackbox exporter: probes on behalf of Prometheus. Prometheus passes the
# target and the module in the scrape URL (/probe?target=...&module=...),
# see the blackbox-* jobs in prometheus.nix. Listens on loopback only.
#
#   icmp     - ping; host up/down for machines and devices (HostDown)
#   http_2xx - web pages from hosts/websites.nix: status, response time,
#              certificate expiry (WebsiteDown, WebsiteSlow,
#              WebsiteCertificateExpiring)
{pkgs, ...}: {
  services.prometheus.exporters.blackbox = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9115;
    configFile = pkgs.writeText "blackbox.yml" (builtins.toJSON {
      modules = {
        icmp = {
          prober = "icmp";
          timeout = "5s";
          icmp.preferred_ip_protocol = "ip4";
        };
        http_2xx = {
          prober = "http";
          timeout = "10s";
          http = {
            preferred_ip_protocol = "ip4";
            follow_redirects = true;
            # Any 2xx answer counts as up (the default).
            valid_status_codes = [];
          };
        };
      };
    });
  };
}
