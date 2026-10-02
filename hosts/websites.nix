# hosts/websites.nix
#
# Web pages probed by the monitoring (lib/monitoring.nix): Prometheus asks
# the blackbox exporter on the monitoring server to fetch each `url` every
# 30 seconds and records whether it answered with a 2xx status, how long it
# took and, for https://, when the certificate expires. Alerts: WebsiteDown,
# WebsiteSlow, WebsiteCertificateExpiring (docs/MONITORING.md).
#
# Adding a page:
#   1. add an entry below; the attribute name is the label shown in
#      Grafana and in alert e-mails ([a-z][a-z0-9-]*);
#   2. `nix flake check`, commit, `colmena apply --on altair`.
# Removing a page: delete its entry and deploy the same way.
#
# The probes run from inside the home network (the monitoring server). A
# public address therefore tests the way out and back through Cloudflare
# or Funnel, not what a visitor outside sees; an external probe is in
# BACKLOG.md.
#
# Fields:
#   url         - required, http:// or https://; redirects are followed
#   description - optional free text
#
# The entries below are placeholders to show the format; replace them with
# the real pages.
{
  grafana = {
    url = "http://192.168.50.150:3000/api/health";
    description = "Grafana on altair (health endpoint)";
  };

  # Internal page, probed for its certificate: pveproxy serves a FreeIPA
  # certificate (valid until 2027-09-13) that the pve exporter verifies;
  # WebsiteCertificateExpiring warns before it runs out. The blackbox
  # exporter checks it against the system CA bundle, which holds the
  # FreeIPA CA (modules/system/certificates.nix).
  pve-web = {
    url = "https://192.168.50.200:8006/";
    description = "Proxmox web UI on pve (FreeIPA certificate)";
  };

  example-public = {
    url = "https://example.com";
    description = "Placeholder for a public page; replace or remove";
  };
}
