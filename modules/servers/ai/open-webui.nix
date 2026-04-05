# modules/servers/ai/open-webui.nix
#
# Open-WebUI — browser-based chat interface for Ollama.
#
# Design decisions:
#   - Runs as an OCI container via virtualisation.oci-containers (Podman backend).
#   - Persistent data at /mnt/data/open-webui (same encrypted disk as models).
#   - Listens on 127.0.0.1:3000 only — Caddy reverse-proxies externally.
#   - Connects to Ollama on the HOST via host.docker.internal (172.17.0.1
#     or the Podman host gateway). We use host networking mode so the
#     container can reach 0.0.0.0:11434 on localhost directly.
#   - WEBUI_SECRET_KEY: set a non-empty value to enable persistent sessions.
#     Use a random string — not security-critical but required for JWT signing.
#
# Ports:
#   3000 — HTTP (Caddy terminates TLS in front)
#
# Volumes:
#   /mnt/data/open-webui  →  /app/backend/data
#
# Access:
#   http://ai.altair.home.lan  (via Caddy, Phase 3)
#   http://localhost:3000      (direct, for testing)
{
  lib,
  ...
}: {
  # Pre-create persistent data directory with correct ownership.
  # open-webui runs as root inside the container (uid 0), so root ownership
  # on the host is correct for the bind mount.
  systemd.tmpfiles.rules = [
    "d /mnt/data/open-webui 0750 root root -"
  ];

  virtualisation.oci-containers.containers.open-webui = {
    image = "ghcr.io/open-webui/open-webui:main";

    # Use host network so the container reaches Ollama on 127.0.0.1:11434
    # without any extra routing complexity.
    # Security note: host networking gives the container full host network
    # visibility. Acceptable here because Open-WebUI is trusted and
    # port 3000 is only exposed to Caddy on localhost.
    extraOptions = [ "--network=host" ];

    environment = {
      # Point at Ollama on the host (reachable via host network mode).
      OLLAMA_BASE_URL          = "http://127.0.0.1:11434";

      # Disable Ollama API key requirement (we don't set one on Ollama).
      OLLAMA_API_KEY           = "";

      # Bind only to localhost — Caddy proxies from outside.
      HOST                     = "127.0.0.1";
      PORT                     = "3000";

      # Required for JWT session signing. Change to any random string.
      # To generate: tr -dc A-Za-z0-9 </dev/urandom | head -c 32
      # TODO: move to SOPS secret in Phase 3 when Caddy lands.
      WEBUI_SECRET_KEY         = "change-me-use-sops-later";

      # Disable telemetry.
      SCARF_NO_ANALYTICS       = "true";
      DO_NOT_TRACK             = "true";
      ANONYMIZED_TELEMETRY     = "false";
    };

    volumes = [
      "/mnt/data/open-webui:/app/backend/data"
    ];

    # Always restart unless explicitly stopped.
    autoStart = true;
  };

  # Ensure the container starts after Ollama is ready and data disk is mounted.
  systemd.services."podman-open-webui" = {
    after    = [ "ollama.service" "mnt-data.mount" ];
    requires = [ "mnt-data.mount" ];
    # Soft dependency on Ollama — Open-WebUI can start without it
    # (just shows "Ollama unreachable" in UI), but we prefer ordering.
    wants    = [ "ollama.service" ];
  };

  # Allow Caddy (Phase 3) to proxy port 3000 on loopback.
  # No external firewall rule needed — host networking + localhost bind.
}
