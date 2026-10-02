# modules/servers/monitoring/mail.nix
#
# Send-only Postfix for alert e-mails. Alertmanager hands mail to
# 127.0.0.1:25; Postfix looks up the recipient domain's MX and delivers
# directly (no relay host, no credentials), the way Checkmk did before.
# While the internet is down Postfix keeps the mail in its queue and
# retries, so alerts about the outage arrive once it is back.
#
# Listens on loopback only; port 25 is not opened in the firewall.
#
# Deliverability: mail from a home address without SPF or a PTR record can
# be rejected or filed as spam by the receiving server. If that happens,
# relay through an authenticated mailbox instead (BACKLOG.md, "Alert mail
# relay"). Troubleshooting: `journalctl -u postfix`, `mailq`
# (docs/MONITORING.md).
{host, ...}: {
  services.postfix = {
    enable = true;
    settings.main = {
      myhostname = "${host.name}.home.lan";
      inet_interfaces = "loopback-only";
      # The home network has no IPv6 route to the internet.
      inet_protocols = "ipv4";
      # Use TLS when the receiving server offers it.
      smtp_tls_security_level = "may";
    };
  };
}
