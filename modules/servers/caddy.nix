# modules/servers/caddy.nix
#
# Caddy reverse proxy — HTTP-only phase (plain LAN, no TLS yet).
#
# Virtual hosts:
#   ai.home.lan      →  Open-WebUI   http://127.0.0.1:3000
#   search.home.lan  →  SearXNG      http://127.0.0.1:8080
#
# TLS plan:
#   Phase 3 (now): plain HTTP on LAN interface only.
#   Phase 4:       Cloudflare Tunnel replaces direct port 80 exposure.
#                  Caddy will terminate TLS from the tunnel connector.
#                  When that happens: remove allowedTCPPorts 80 here and
#                  configure the tunnel to forward to localhost:80.
#
# Firewall:
#   Port 80 opened on enp10s0 (LAN) ONLY — not globally.
#   Port 443 intentionally closed — no self-signed cert complexity.
#   Port 2019 (Caddy admin API) stays on localhost only (NixOS default).
#
# DNS (FreeIPA home.lan zone — already configured):
#   ai.home.lan     A  192.168.50.150
#   search.home.lan A  192.168.50.150
#
# Security notes:
#   - Plain HTTP acceptable for home LAN with trusted devices.
#   - Open-WebUI and SearXNG are bound to 127.0.0.1 — only Caddy can
#     reach them, not direct LAN connections to port 3000/8080.
#   - Caddy strips the X-Forwarded-For header from upstream to prevent
#     spoofing; Open-WebUI's WEBUI_SECRET_KEY still protects sessions.
{...}: {
  services.caddy = {
    enable = true;

    # Global options block — disable automatic HTTPS since we're HTTP-only.
    # Caddy normally redirects HTTP→HTTPS automatically; disable that here.
    # When Cloudflare Tunnel is added in Phase 4, re-evaluate this block.
    globalConfig = ''
      auto_https off
      admin localhost:2019
    '';

    virtualHosts = {
      # ------------------------------------------------------------------
      # Open-WebUI — LLM chat interface
      # ------------------------------------------------------------------
      "http://ai.home.lan" = {
        extraConfig = ''
          # Proxy to Open-WebUI container (host network, localhost:3000)
          reverse_proxy 127.0.0.1:3000 {
            # Pass real client IP to Open-WebUI for audit logs.
            header_up X-Real-IP {remote_host}
            # Increase timeouts for long LLM streaming responses.
            # Default 30s is too short for large model completions.
            transport http {
              response_header_timeout 300s
              dial_timeout 10s
            }
          }
          # Encode responses with gzip for faster UI loading.
          encode gzip
        '';
      };

      # ------------------------------------------------------------------
      # SearXNG — internal search (used by Open-WebUI web search tool)
      # Exposed on LAN so you can also use it directly from a browser.
      # ------------------------------------------------------------------
      "http://search.home.lan" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8080 {
            header_up X-Real-IP {remote_host}
            transport http {
              response_header_timeout 30s
              dial_timeout 5s
            }
          }
          encode gzip
        '';
      };
    };
  };

  # Open port 80 on the LAN interface only.
  # NOT added to networking.firewall.allowedTCPPorts (which applies globally).
  # enp10s0 = Intel I226-V 2.5G LAN NIC (192.168.50.150)
  networking.firewall.interfaces."enp10s0".allowedTCPPorts = [80];

  # Caddy must start after both containers are up.
  # 'wants' not 'requires' — Caddy starts even if a container is down,
  # it will just return 502 until the backend recovers.
  systemd.services.caddy = {
    after = [
      "podman-open-webui.service"
      "podman-searxng.service"
    ];
    wants = [
      "podman-open-webui.service"
      "podman-searxng.service"
    ];
  };
}
