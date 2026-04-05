# modules/servers/ai/open-webui.nix
#
# Open-WebUI — browser-based chat interface for Ollama.
#
# Design decisions:
#   - Runs as an OCI container via virtualisation.oci-containers (Podman backend).
#   - Persistent data at /mnt/data/open-webui (same encrypted disk as models).
#   - Port mapping: 127.0.0.1:3001->8080 (container internal always 8080).
#     Port 3000 is taken by Grafana on this host.
#     We publish ONLY to loopback so Caddy is the only entry point from LAN.
#   - Ollama is reached via host-gateway (Podman special DNS name that resolves
#     to the host IP from inside the container). No host networking needed.
#
# Port conflict history:
#   :8080 — conflict with SearXNG (both host-network) → switched to port mapping
#   :3000 — conflict with Grafana → moved to :3001
#
# Boot-ordering:
#   ExecStartPre with + prefix (root) creates /mnt/data/open-webui after
#   mnt-data.mount is satisfied. Same pattern as ollama.nix.
#
# Ports:
#   host 127.0.0.1:3001  →  container :8080
#
# Volumes:
#   /mnt/data/open-webui  →  /app/backend/data
{pkgs, ...}: {
  virtualisation.oci-containers.containers.open-webui = {
    image = "ghcr.io/open-webui/open-webui:main";

    # 127.0.0.1:3001 on host → 8080 inside container.
    # Loopback-only: Caddy is the sole external entry point.
    ports = ["127.0.0.1:3001:8080"];

    # host-gateway resolves to the host IP inside the container,
    # allowing the container to reach Ollama on the host.
    extraOptions = ["--add-host=host-gateway:host-gateway"];

    environment = {
      OLLAMA_BASE_URL = "http://host-gateway:11434";
      OLLAMA_API_KEY = "";
      # TODO Phase 4: replace with sops secret
      # Generate with: tr -dc A-Za-z0-9 </dev/urandom | head -c 32
      WEBUI_SECRET_KEY = "change-me-use-sops-later";
      SCARF_NO_ANALYTICS = "true";
      DO_NOT_TRACK = "true";
      ANONYMIZED_TELEMETRY = "false";
    };

    volumes = [
      "/mnt/data/open-webui:/app/backend/data"
    ];

    autoStart = true;
  };

  systemd.services."podman-open-webui" = {
    after = ["mnt-data.mount" "ollama.service"];
    requires = ["mnt-data.mount"];
    wants = ["ollama.service"];

    serviceConfig = {
      ExecStartPre = [
        "+${pkgs.coreutils}/bin/mkdir -p /mnt/data/open-webui"
        "+${pkgs.coreutils}/bin/chown root:root /mnt/data/open-webui"
        "+${pkgs.coreutils}/bin/chmod 0750 /mnt/data/open-webui"
      ];
    };
  };
}
