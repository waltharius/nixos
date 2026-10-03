# modules/servers/monitoring/grafana.nix
#
# Grafana on the monitoring server (lib/monitoring.nix, docs/MONITORING.md).
# Phase A: accessible at http://<monitoring server>:3000 (LAN IP, no TLS).
# Phase B (later): a reverse proxy serves grafana.home.lan with TLS; then
#                  set domain, root_url, cookie_secure = true.
#
# Everything Grafana shows is provisioned from this file: the Prometheus
# and Alertmanager data sources, the community dashboards below and the
# repository's own dashboards in ./dashboards/ (the home dashboard "Fleet
# overview" lists active alerts and what is up or down). Nothing
# is configured by hand in the UI, so grafana.db holds no state worth
# keeping (metrics live in Prometheus, not in Grafana).
#
# Alerts: Alerting -> Alert rules lists the Prometheus rules with their
# state (view "State" groups them like Checkmk's problem list); Alerting ->
# Silences (choose the Alertmanager data source) mutes alerts during
# maintenance.
#
# Firewall: port 3000 allowed on the LAN interface only.
# Admin password: SOPS secret -> /run/secrets/grafana-admin-password
#                 File must contain a single line: GF_SECURITY_ADMIN_PASSWORD=<pass>
# Secret key:     SOPS secret -> /run/secrets/grafana-secret-key (raw value, no KEY= prefix)
#                 Read by Grafana's file provider at startup, never lands in the Nix store.
#                 Grafana encrypts secrets stored in grafana.db with it and cannot
#                 switch an existing database to a new key; replacing the key means
#                 starting with an empty grafana.db (refactor stage 5a did this once
#                 to leave the publicly known pre-26.05 default behind, CHANGELOG.md).
{
  config,
  lib,
  pkgs,
  host,
  ...
}: let
  # Dashboards defined in Nix (./dashboards/<name>.nix -> <name>.json).
  fleetDashboards = pkgs.linkFarm "grafana-fleet-dashboards" [
    {
      name = "fleet-overview.json";
      path = pkgs.writeText "fleet-overview.json" (builtins.toJSON (import ./dashboards/fleet-overview.nix));
    }
  ];
in {
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0"; # nftables restricts to LAN
        http_port = 3000;
        # Absolute URLs Grafana builds (share links, image export, links in
        # notifications) use root_url; without it they point to
        # http://localhost:3000, i.e. the viewer's own machine.
        # Phase B: https://grafana.home.lan behind Caddy.
        root_url = "http://${host.name}.${config.networking.domain}:3000/";
      };
      security = {
        admin_user = "admin";
        # password comes from EnvironmentFile below (SOPS secret)
        # nixpkgs 26.05: secret_key has no default anymore. "$__file{...}" is
        # Grafana's file provider syntax (not Nix interpolation — only ${ is).
        secret_key = "$__file{${config.sops.secrets.grafana-secret-key.path}}";
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
      # Grafana 12+ downloads and auto-updates a set of "preinstalled" plugins
      # (drilldown apps, decoupled core datasources) from grafana.com at every
      # start. That is non-declarative, needs internet at boot, and would try to
      # replace bundled plugins that live read-only in the Nix store.
      # Bundled plugin versions now move with the Grafana package instead.
      plugins.preinstall_disabled = true;
      # Opening Grafana shows the fleet overview (active alerts, up/down).
      dashboards.default_home_dashboard_path = "${fleetDashboards}/fleet-overview.json";
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
              # Show the Prometheus alert rules under Alerting -> Alert rules.
              manageAlerts = true;
              alertmanagerUid = "alertmanager";
            };
          }
          {
            name = "Alertmanager";
            type = "alertmanager";
            uid = "alertmanager";
            url = "http://127.0.0.1:${toString config.services.prometheus.alertmanager.port}";
            access = "proxy";
            jsonData = {
              implementation = "prometheus";
              # Grafana-managed alerts are not used; all rules live in Prometheus.
              handleGrafanaManagedAlerts = false;
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
          # Dashboards written in this repository (./dashboards/*.nix),
          # read-only in the Nix store.
          {
            name = "fleet";
            type = "file";
            disableDeletion = true;
            allowUiUpdates = false;
            options.path = fleetDashboards;
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
  # Download is guarded by file existence (idempotent): a dashboard is
  # fetched once and then kept. To get a newer revision, delete its file in
  # /var/lib/grafana/dashboards and restart grafana.
  #
  # Patching runs on every start for every file: grafana.com API downloads
  # use the "export for sharing" format with __inputs/__requires sections,
  # which Grafana's file provisioner does NOT process - it silently skips
  # the file. jq strips those sections and sed replaces the
  # ${DS_PROMETHEUS} datasource variable with the UID of the provisioned
  # Prometheus data source ("prometheus"). Dashboards without an automatic
  # refresh get one of 1m (it runs only while the dashboard is open; the
  # picker at the top right overrides it per view); a refresh set by the
  # dashboard's author is kept. All steps are idempotent.
  #
  # Note on Nix string escaping: inside ''...'' strings, ${ is still
  # interpreted as Nix interpolation. Use ''${ to emit a literal ${.
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
        # Blackbox exporter probes: hosts up/down, websites, response times
        # (updated version of dashboard 7587)
        "blackbox.json" = "https://grafana.com/api/dashboards/15873/revisions/latest/download";
        # Proxmox via Prometheus (pve exporter, job pve): host, guests, storage
        "proxmox.json" = "https://grafana.com/api/dashboards/10347/revisions/latest/download";
        # Cadvisor exporter (job cadvisor): CPU, memory, network per container
        "cadvisor.json" = "https://grafana.com/api/dashboards/14282/revisions/latest/download";
        # UPS statistics, the nut exporter's own dashboard (job nut), pinned
        # to the exporter version in nixpkgs
        "ups.json" = "https://raw.githubusercontent.com/DRuggeri/nut_exporter/v3.2.5/dashboard/dashboard.json";
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

      for f in /var/lib/grafana/dashboards/*.json; do
        [ -f "$f" ] || continue
        echo "Patching $f: stripping __inputs/__requires/__elements, default refresh, fixing datasource UID"
        ${pkgs.jq}/bin/jq 'del(.__inputs) | del(.__requires) | del(.__elements)
          | if ((.refresh // "") | tostring) == "" or .refresh == false then .refresh = "1m" else . end' "$f" > "$f.tmp" \
          && mv "$f.tmp" "$f"
        ${pkgs.gnused}/bin/sed -i \
          's/"''${DS_PROMETHEUS}"/"prometheus"/g;s/"''${ds_prometheus}"/"prometheus"/g' \
          "$f"
      done
    '';
  };

  sops.secrets.grafana-admin-password = {
    sopsFile = ../../../secrets/altair.yaml;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
    # Key in secrets/altair.yaml: grafana-admin-password
  };

  sops.secrets.grafana-renderer-token = {
    sopsFile = ../../../secrets/altair.yaml;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
    # Key in secrets/altair.yaml: grafana-renderer-token (raw value, e.g.
    # from `openssl rand -hex 32`)
  };

  sops.secrets.grafana-secret-key = {
    sopsFile = ../../../secrets/altair.yaml;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
    # Key in secrets/altair.yaml: grafana-secret-key (raw value, no KEY= prefix)
  };

  # Image rendering: "Share -> Export as image" and the render links of
  # panels. Grafana hands the rendering to a separate service that drives a
  # headless Chromium; `provisionGrafana` points Grafana at it (and the
  # callback URL back to Grafana). The renderer listens on localhost:8081
  # only. Pulls in Chromium.
  #
  # Shared token: Grafana sends it in X-Auth-Token, the renderer accepts
  # only requests carrying it. Grafana 13 refuses to start with the default
  # token ("-"). One sops value feeds both sides: Grafana reads the raw
  # file, the renderer gets AUTH_TOKEN from an environment file rendered by
  # sops-nix (its systemd unit uses a dynamic user, so the file is read by
  # systemd as root).
  services.grafana-image-renderer = {
    enable = true;
    provisionGrafana = true;
  };

  services.grafana.settings.rendering.renderer_token = "$__file{${config.sops.secrets.grafana-renderer-token.path}}";

  systemd.services.grafana-image-renderer.serviceConfig.EnvironmentFile =
    config.sops.templates."grafana-image-renderer.env".path;

  sops.templates."grafana-image-renderer.env".content = ''
    AUTH_TOKEN=${config.sops.placeholder.grafana-renderer-token}
  '';

  # Firewall rule: allow Grafana from the LAN interface only
  # (`lan.interface` in hosts/machines/<host>.nix), so Grafana is not
  # reachable from Incus containers (incusbr0). pfSense blocks WAN->LAN.
  networking.firewall.interfaces.${host.lan.interface}.allowedTCPPorts = [3000];

  # If you later want to also allow from incusbr0 (for a Caddy container):
  # networking.firewall.interfaces."incusbr0".allowedTCPPorts = [ 3000 ];
}
