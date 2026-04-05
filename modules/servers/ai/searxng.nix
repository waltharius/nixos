# modules/servers/ai/searxng.nix
#
# SearXNG — privacy-respecting metasearch engine.
# Used by Open-WebUI's web search tool to give the LLM internet access.
#
# Design decisions:
#   - OCI container (Podman) via virtualisation.oci-containers.
#   - settings.yml written by ExecStartPre on every service start (idempotent).
#   - secret_key generated once, stored in /mnt/data/searxng/secret_key.
#   - Binds 0.0.0.0:8080 so Open-WebUI container can reach it via host-gateway.
#   - JSON format explicitly enabled — SearXNG blocks ?format=json by default
#     as a bot-protection measure. Internal use requires it explicitly allowed.
#
# Ports:
#   8080 — HTTP, 0.0.0.0 (firewall restricts to lo + podman bridges, blocks LAN)
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
      # Not a public instance — disables public-facing bot protections.
      public_instance: false

    ui:
      default_locale: "en"
      default_theme: simple
      center_alignment: true

    search:
      safe_search: 0
      autocomplete: ""
      default_lang: "en"
      # Must explicitly allow json format — SearXNG blocks it by default
      # to prevent scraping on public instances. Required for Open-WebUI.
      formats:
        - html
        - json

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

  # Port 8080 (SearXNG) and 11434 (Ollama) allowed on Podman bridges only.
  # LAN (enp10s0) access to both ports stays blocked.
  networking.firewall.interfaces."podman0".allowedTCPPorts     = [ 11434 8080 ];
  networking.firewall.interfaces."podman1".allowedTCPPorts     = [ 11434 8080 ];
  networking.firewall.interfaces."cni-podman0".allowedTCPPorts = [ 11434 8080 ];
}
