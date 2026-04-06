# modules/servers/caddy.nix
#
# Caddy reverse proxy — HTTP-only phase (plain LAN, no TLS yet).
#
# Virtual hosts:
#   ai.home.lan      →  Open-WebUI   http://127.0.0.1:3001
#   search.home.lan  →  SearXNG      http://127.0.0.1:8080
#
# Port map (host loopback):
#   3001 — Open-WebUI  (3000 is taken by Grafana)
#   8080 — SearXNG     (host-network, binds 127.0.0.1:8080)
#   2019 — Caddy admin API (localhost only, NixOS default)
#
# TLS plan:
#   Phase 3 (now): plain HTTP on LAN interface only.
#   Phase 4:       Cloudflare Tunnel replaces direct port 80 exposure.
#
# Firewall:
#   Port 80 opened on enp10s0 (LAN) ONLY — not globally.
#   Port 443 intentionally closed.
#
# DNS (FreeIPA home.lan zone — already configured):
#   ai.home.lan     A  192.168.50.150
#   search.home.lan A  192.168.50.150
{...}: {
  services.caddy = {
    enable = true;

    # Disable automatic HTTPS — HTTP-only until Cloudflare Tunnel in Phase 4.
    globalConfig = ''
      auto_https off
      admin localhost:2019
    '';

    virtualHosts = {
      "http://ai.home.lan" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:3001 {
            header_up X-Real-IP {remote_host}
            # 300s timeout for long LLM streaming responses.
            transport http {
              response_header_timeout 300s
              dial_timeout 10s
            }
          }
          encode gzip
        '';
      };

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

      "http://ollama.home.lan" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:11434 {
            header_up X-Real-IP {remote_host}
            transport http {
              response_header_timeout 600s
              dial_timeout 10s
            }
          }
          encode gzip
        '';
      };
    };
  };

  # Port 80 on LAN interface only — not globally.
  networking.firewall.interfaces."enp10s0".allowedTCPPorts = [80];

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
