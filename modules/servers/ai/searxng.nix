# modules/servers/ai/searxng.nix
#
# SearXNG — privacy-respecting metasearch engine.
# Used by Open-WebUI's web search tool to give the LLM internet access.
#
# Design decisions:
#   - OCI container (Podman) via virtualisation.oci-containers.
#   - settings.yml written by ExecStartPre on every service start,
#     so config is always in sync with Nix without a separate activation script.
#   - secret_key is generated once and stored in /mnt/data/searxng/secret_key.
#     It is NOT regenerated on subsequent starts (idempotent check).
#   - Listens on 127.0.0.1:8080 only — not reachable from LAN directly.
#
# Boot-ordering:
#   Same as open-webui.nix — ExecStartPre with + prefix, after mnt-data.mount.
#   No tmpfiles.rules, no activationScripts (those run too early / wrong order).
#
# Ports:
#   8080 — HTTP, 127.0.0.1 only
#
# Volumes:
#   /mnt/data/searxng  →  /etc/searxng
{pkgs, ...}: let
  # Write settings.yml as a Nix-managed file in the Nix store.
  # The actual secret_key line is filled in at runtime by the shell script
  # in ExecStartPre (it reads /mnt/data/searxng/secret_key).
  settingsTemplate = pkgs.writeText "searxng-settings-template.yml" ''
    # SearXNG settings — written by NixOS ExecStartPre on each service start.
    # secret_key is injected from /mnt/data/searxng/secret_key at runtime.
    use_default_settings: true

    server:
      secret_key: "__SECRET_KEY__"
      limiter: false
      image_proxy: true
      base_url: "http://localhost:8080/"
      bind_address: "127.0.0.1:8080"

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

  # Shell script run as root before the container starts.
  # 1. Creates /mnt/data/searxng if missing.
  # 2. Generates secret_key once (idempotent).
  # 3. Writes settings.yml with secret_key substituted.
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
    extraOptions = ["--network=host"];

    environment = {
      SEARXNG_BIND_ADDRESS = "127.0.0.1:8080";
      SEARXNG_SETTINGS_PATH = "/etc/searxng";
    };

    volumes = [
      "/mnt/data/searxng:/etc/searxng:rw"
    ];

    autoStart = true;
  };

  systemd.services."podman-searxng" = {
    after = ["mnt-data.mount"];
    requires = ["mnt-data.mount"];

    serviceConfig = {
      # + prefix: runs as root, after mount ordering is satisfied.
      ExecStartPre = ["+${prepScript}"];
    };
  };
}
