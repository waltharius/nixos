# modules/servers/monitoring/grafana.nix
#
# Grafana visualization layer.
# Phase A: accessible at http://192.168.50.150:3000 (LAN IP, no TLS).
# Phase B (later): Caddy on Dell (192.168.50.114) proxies grafana.home.lan
#                  -> 192.168.50.150:3000 with FreeIPA-issued cert.
#                  At that point: set domain, root_url, cookie_secure = true.
#
# Firewall: port 3000 allowed from 192.168.50.0/24 only (see hardening.nix).
# Admin password: SOPS secret → /run/secrets/grafana-admin-password
#                 File must contain a single line: GF_SECURITY_ADMIN_PASSWORD=<pass>
{
  config,
  lib,
  pkgs,
  ...
}: {
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0"; # nftables restricts to LAN
        http_port = 3000;
        # Phase B: uncomment and set when Caddy proxy is live:
        # domain   = "grafana.home.lan";
        # root_url = "https://grafana.home.lan";
        plugins = {
          enable_alpha = false;
        };
      };
      security = {
        admin_user = "admin";
        # password comes from EnvironmentFile below (SOPS secret)
        disable_gravatar = true;
        cookie_secure = false; # Phase B: set true when behind TLS proxy
        cookie_samesite = "lax";
      };
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
        feedback_links_enabled = false;
      };
      users.allow_sign_up = false;
      "auth.anonymous".enabled = false;
    };

    provision = {
      enable = true;

      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:9090";
            access = "proxy";
            isDefault = true;
            uid = "prometheus";
            jsonData = {
              timeInterval = "15s";
            };
          }
        ];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "provisioned";
            type = "file";
            disableDeletion = true; # prevent accidental deletion via UI
            updateIntervalSeconds = 30;
            options.path = "/var/lib/grafana/dashboards";
          }
        ];
      };
    };
  };

  # Inject SOPS-managed admin password as an environment variable.
  # The secret file must contain exactly one line:
  #   GF_SECURITY_ADMIN_PASSWORD=yourpassword
  systemd.services.grafana.serviceConfig.EnvironmentFile =
    config.sops.secrets.grafana-admin-password.path;

  # Pre-download community dashboards before Grafana starts.
  # Idempotent: skips download if file already exists.
  # Dashboards are re-fetched on nixos-rebuild if files are absent
  # (e.g. after a fresh install or /var/lib wipe).
  systemd.services.grafana-provision-dashboards = {
    description = "Download Grafana community dashboards";
    wantedBy = ["grafana.service"];
    before = ["grafana.service"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "grafana";
      Group = "grafana";
    };
    script = let
      dashboards = {
        # Node Exporter Full - system-wide hardware/OS metrics
        "node-exporter-full.json" = "https://grafana.com/api/dashboards/1860/revisions/latest/download";
        # NVIDIA GPU metrics (works with nvidia-smi exporter we add in Phase C)
        "nvidia-gpu.json" = "https://grafana.com/api/dashboards/14574/revisions/latest/download";
      };
      downloads = lib.concatStrings (lib.mapAttrsToList (file: url: ''
          if [ ! -f "/var/lib/grafana/dashboards/${file}" ]; then
            echo "Downloading dashboard: ${file}"
            ${pkgs.curl}/bin/curl -fsSL "${url}" \
              -o "/var/lib/grafana/dashboards/${file}" || \
              echo "WARNING: failed to download ${file}, continuing"
          fi
        '')
        dashboards);
    in ''
      mkdir -p /var/lib/grafana/dashboards
      ${downloads}
    '';
  };

  sops.secrets.grafana-admin-password = {
    sopsFile = ../../../secrets/altair.yaml;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
    # Key in secrets/altair.yaml: grafana-admin-password
  };

  # Firewall rule: allow Grafana from LAN interface only.
  # pfSense is the perimeter - it blocks WAN→LAN:3000 already.
  # Restricting to enp10s0 (LAN NIC) ensures Grafana is unreachable
  # from Incus containers (incusbr0) and the internet.
  networking.firewall.interfaces."enp10s0".allowedTCPPorts = [3000];

  # If you later want to also allow from incusbr0 (for a Caddy container):
  # networking.firewall.interfaces."incusbr0".allowedTCPPorts = [ 3000 ];
}
