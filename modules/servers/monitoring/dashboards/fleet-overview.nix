# modules/servers/monitoring/dashboards/fleet-overview.nix
#
# "Fleet overview" - the Grafana home dashboard: what is wrong right now,
# at a glance, like Checkmk's main view. Provisioned by grafana.nix from
# this file (Nix data -> JSON); edits made in the Grafana UI are not kept,
# change this file instead.
#
# Panels:
#   Active alerts  - every pending or firing Prometheus alert except the
#                    always-firing Watchdog (the ALERTS series Prometheus
#                    writes for each alert); empty table = nothing wrong
#   Hosts (ping)   - UP/DOWN tile per pinged machine and device
#   Websites       - UP/DOWN tile per page in hosts/websites.nix
#   Exporters      - UP/DOWN tile per scraped exporter
#   Website response time, certificate expiry
let
  ds = {
    type = "prometheus";
    uid = "prometheus";
  };

  target = expr: legend: {
    refId = "A";
    datasource = ds;
    inherit expr;
    legendFormat = legend;
  };

  upDownTiles = id: title: description: gridPos: expr: legend: {
    inherit id title description gridPos;
    type = "stat";
    datasource = ds;
    targets = [(target expr legend // {instant = true;})];
    options = {
      reduceOptions = {
        calcs = ["lastNotNull"];
        fields = "";
        values = false;
      };
      colorMode = "background";
      graphMode = "none";
      textMode = "value_and_name";
      justifyMode = "auto";
      orientation = "auto";
      wideLayout = true;
      showPercentChange = false;
    };
    fieldConfig = {
      defaults = {
        color.mode = "thresholds";
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "red";
              value = null;
            }
            {
              color = "green";
              value = 1;
            }
          ];
        };
        mappings = [
          {
            type = "value";
            options = {
              "0" = {
                text = "DOWN";
                color = "red";
                index = 0;
              };
              "1" = {
                text = "UP";
                color = "green";
                index = 1;
              };
            };
          }
        ];
        noValue = "no targets";
      };
      overrides = [];
    };
  };
in {
  uid = "fleet-overview";
  title = "Fleet overview";
  tags = ["fleet" "alerts"];
  timezone = "browser";
  schemaVersion = 39;
  version = 1;
  editable = false;
  refresh = "30s";
  time = {
    from = "now-6h";
    to = "now";
  };
  templating.list = [];
  annotations.list = [];

  panels = [
    {
      id = 1;
      type = "table";
      title = "Active alerts";
      description = "Pending (waiting for its `for` duration) and firing Prometheus alerts. Empty = nothing wrong. Details and silences: Alerting in the menu.";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 0;
      };
      datasource = ds;
      targets = [
        (target ''ALERTS{alertname!="Watchdog"}'' ""
          // {
            instant = true;
            format = "table";
          })
      ];
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              Value = true;
              __name__ = true;
              job = true;
              class = true;
              baremetal = true;
              kind = true;
            };
            renameByName = {
              alertname = "Alert";
              alertstate = "State";
              severity = "Severity";
              host = "Host";
              instance = "Instance";
            };
            indexByName = {
              alertname = 0;
              alertstate = 1;
              severity = 2;
              host = 3;
              instance = 4;
            };
          };
        }
      ];
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
        sortBy = [
          {
            displayName = "Severity";
            desc = false;
          }
        ];
      };
      fieldConfig = {
        defaults = {};
        overrides = [
          {
            matcher = {
              id = "byName";
              options = "Severity";
            };
            properties = [
              {
                id = "custom.cellOptions";
                value.type = "color-background";
              }
              {
                id = "mappings";
                value = [
                  {
                    type = "value";
                    options = {
                      critical = {
                        color = "red";
                        index = 0;
                      };
                      warning = {
                        color = "orange";
                        index = 1;
                      };
                      info = {
                        color = "blue";
                        index = 2;
                      };
                    };
                  }
                ];
              }
            ];
          }
        ];
      };
    }

    (upDownTiles 2 "Hosts (ping)"
      "Machines and devices pinged by the monitoring server (hosts/machines/, hosts/devices/ with monitoring.ping)." {
        h = 7;
        w = 24;
        x = 0;
        y = 8;
      }
      ''probe_success{job="blackbox-icmp"}'' "{{instance}}")

    (upDownTiles 3 "Websites" "Pages from hosts/websites.nix." {
        h = 5;
        w = 8;
        x = 0;
        y = 15;
      }
      ''probe_success{job="blackbox-http"}'' "{{instance}}")

    (upDownTiles 4 "Exporters" "Exporters Prometheus scrapes (node_exporter, smartctl_exporter, GPU, the monitoring stack)." {
        h = 5;
        w = 16;
        x = 8;
        y = 15;
      }
      ''up{job!~"blackbox-.*"}'' "{{instance}} {{job}}")

    {
      id = 5;
      type = "timeseries";
      title = "Website response time";
      gridPos = {
        h = 8;
        w = 16;
        x = 0;
        y = 20;
      };
      datasource = ds;
      targets = [(target ''probe_duration_seconds{job="blackbox-http"}'' "{{instance}}")];
      fieldConfig = {
        defaults = {
          unit = "s";
          custom = {
            drawStyle = "line";
            lineWidth = 1;
            fillOpacity = 0;
            showPoints = "never";
          };
        };
        overrides = [];
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
          showLegend = true;
        };
        tooltip.mode = "multi";
      };
    }

    {
      id = 6;
      type = "stat";
      title = "Certificates: days left";
      description = "Days until the TLS certificate of each https:// page expires. WebsiteCertificateExpiring fires below 14.";
      gridPos = {
        h = 8;
        w = 8;
        x = 16;
        y = 20;
      };
      datasource = ds;
      targets = [
        (target ''(probe_ssl_earliest_cert_expiry{job="blackbox-http"} - time()) / 86400'' "{{instance}}"
          // {instant = true;})
      ];
      options = {
        reduceOptions = {
          calcs = ["lastNotNull"];
          fields = "";
          values = false;
        };
        colorMode = "value";
        graphMode = "none";
        textMode = "value_and_name";
        justifyMode = "auto";
        orientation = "horizontal";
        wideLayout = true;
        showPercentChange = false;
      };
      fieldConfig = {
        defaults = {
          decimals = 0;
          unit = "none";
          color.mode = "thresholds";
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "red";
                value = null;
              }
              {
                color = "orange";
                value = 14;
              }
              {
                color = "green";
                value = 30;
              }
            ];
          };
          noValue = "no https pages";
        };
        overrides = [];
      };
    }
  ];
}
