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
  #
  # Download is guarded by file existence (idempotent).
  # Patching is always re-run so it applies correctly after every
  # colmena deploy without needing to manually delete cached JSON.
  #
  # Why the nvidia-gpu dashboard needs patching:
  #   grafana.com API downloads use the "export for sharing" format which
  #   includes __inputs/__requires sections. Grafana's file provisioner does
  #   NOT process this format and silently skips the file entirely - making
  #   the dashboard invisible in the UI. We use jq to strip those sections,
  #   then sed to replace the ''${DS_PROMETHEUS} datasource variable reference
  #   with the hard-coded UID of our provisioned datasource ("prometheus").
  #
  # Note on Nix string escaping: inside ''...'' strings, ${ is still
  # interpreted as Nix interpolation. Use ''${ to emit a literal ${ in
  # the resulting shell script (i.e. ''${DS_PROMETHEUS} -> ${DS_PROMETHEUS}).
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
        # NVIDIA GPU metrics (nvidia-smi exporter, utkuozdemir/nvidia_gpu_exporter)
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

      # Strip __inputs / __requires / __elements so Grafana's file provisioner
      # can load the dashboard (it silently skips files containing these
      # export-format sections). Then replace the datasource variable reference
      # with the hard-coded UID of our provisioned Prometheus datasource.
      # Runs on every service start - both operations are idempotent.
      if [ -f "/var/lib/grafana/dashboards/nvidia-gpu.json" ]; then
        echo "Patching nvidia-gpu.json: stripping __inputs/__requires and fixing datasource UID"
        ${pkgs.jq}/bin/jq 'del(.__inputs) | del(.__requires) | del(.__elements)' \
          /var/lib/grafana/dashboards/nvidia-gpu.json \
          > /tmp/nvidia-gpu-clean.json \
          && mv /tmp/nvidia-gpu-clean.json /var/lib/grafana/dashboards/nvidia-gpu.json
        ${pkgs.gnused}/bin/sed -i \
          's/"''${DS_PROMETHEUS}"/"prometheus"/g;s/"''${ds_prometheus}"/"prometheus"/g' \
          /var/lib/grafana/dashboards/nvidia-gpu.json
        echo "Patching nvidia-gpu.json: done"
      fi
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
  # pfSense is the perimeter - it blocks WAN->LAN:3000 already.
  # Restricting to enp10s0 (LAN NIC) ensures Grafana is unreachable
  # from Incus containers (incusbr0) and the internet.
  networking.firewall.interfaces."enp10s0".allowedTCPPorts = [3000];

  # If you later want to also allow from incusbr0 (for a Caddy container):
  # networking.firewall.interfaces."incusbr0".allowedTCPPorts = [ 3000 ];
}
