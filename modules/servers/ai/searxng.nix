# modules/servers/ai/searxng.nix
#
# SearXNG — privacy-respecting metasearch engine.
# Used by Open-WebUI's web search tool to give the LLM internet access.
#
# Design decisions:
#   - OCI container (Podman) via virtualisation.oci-containers.
#   - settings.yml written by ExecStartPre on every service start (idempotent).
#   - secret_key generated once, stored in /mnt/data/searxng/secret_key.
#   - Binds 0.0.0.0:8080 (all interfaces) so Open-WebUI container can reach
#     it via host-gateway (10.88.0.1). Firewall blocks LAN access.
#
# Why 0.0.0.0 and not 127.0.0.1:
#   Open-WebUI runs in a Podman container. It reaches the host via
#   host-gateway (10.88.0.1 on podman0 bridge). 127.0.0.1 is the
#   container's OWN loopback, not the host's. SearXNG must bind all
#   interfaces so the podman0 bridge IP (10.88.0.1) accepts connections.
#   Firewall rule on enp10s0 blocks direct LAN access to port 8080.
#
# Boot-ordering:
#   ExecStartPre with + prefix (root), after mnt-data.mount.
#
# Ports:
#   8080 — HTTP, 0.0.0.0 (firewall restricts to lo + podman0, blocks LAN)
#
# Volumes:
#   /mnt/data/searxng  →  /etc/searxng
{pkgs, ...}: let
  settingsTemplate = pkgs.writeText "searxng-settings-template.yml" ''
    # SearXNG settings — written by NixOS ExecStartPre on each service start.
    # secret_key is injected from /mnt/data/searxng/secret_key at runtime.
    use_default_settings: true

    server:
      secret_key: "__SECRET_KEY__"
      limiter: false
      image_proxy: true
      base_url: "http://search.home.lan/"
      bind_address: "0.0.0.0:8080"

    ui:
      default_locale: "en"
      default_theme: simple
      center_alignment: true

    search:
      safe_search: 0
      autocomplete: ""
      default_lang: "en"

    engines:
      - name: google
        engine: google
        shortcut: g
      - name: duckduckgo
        engine: duckduckgo
        shortcut: d
      - name: wikipedia
        engine: wikipedia
        shortcut: w
        base_url: "https://en.wikipedia.org/"
      - name: github
        engine: github
        shortcut: gh
  '';

  prepScript = pkgs.writeShellScript "searxng-prep" ''
    set -euo pipefail
    install -d -m 0750 /mnt/data/searxng

    KEY_FILE=/mnt/data/searxng/secret_key
    if [ ! -f "$KEY_FILE" ]; then
      ${pkgs.openssl}/bin/openssl rand -hex 32 > "$KEY_FILE"
      chmod 0600 "$KEY_FILE"
    fi
    SECRET_KEY=$(cat "$KEY_FILE")

    ${pkgs.gnused}/bin/sed "s/__SECRET_KEY__/$SECRET_KEY/g" \
      ${settingsTemplate} > /mnt/data/searxng/settings.yml
    chmod 0640 /mnt/data/searxng/settings.yml
  '';
in {
  virtualisation.oci-containers.containers.searxng = {
    image = "docker.io/searxng/searxng:latest";
    extraOptions = [ "--network=host" ];

    environment = {
      # Bind all interfaces — firewall restricts access, not the bind address.
      SEARXNG_BIND_ADDRESS  = "0.0.0.0:8080";
      SEARXNG_SETTINGS_PATH = "/etc/searxng";
    };

    volumes = [
      "/mnt/data/searxng:/etc/searxng:rw"
    ];

    autoStart = true;
  };

  systemd.services."podman-searxng" = {
    after    = [ "mnt-data.mount" ];
    requires = [ "mnt-data.mount" ];
    serviceConfig.ExecStartPre = [ "+${prepScript}" ];
  };

  # SearXNG port 8080 access control:
  #   ALLOW: lo        (localhost — Caddy proxy, curl tests)
  #   ALLOW: podman0   (Open-WebUI container via host-gateway)
  #   BLOCK: enp10s0   (LAN — users access via Caddy on port 80 only)
  networking.firewall.interfaces."podman0".allowedTCPPorts     = [ 11434 8080 ];
  networking.firewall.interfaces."podman1".allowedTCPPorts     = [ 11434 8080 ];
  networking.firewall.interfaces."cni-podman0".allowedTCPPorts = [ 11434 8080 ];
}
