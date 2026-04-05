# modules/servers/ai/open-webui.nix
#
# Open-WebUI — browser-based chat interface for Ollama.
#
# Design decisions:
#   - Runs as an OCI container via virtualisation.oci-containers (Podman backend).
#   - Persistent data at /mnt/data/open-webui (same encrypted disk as models).
#   - Listens on 127.0.0.1:3000 only — Caddy reverse-proxies externally.
#   - Uses host networking so the container reaches Ollama on 127.0.0.1:11434
#     directly without extra routing.
#   - WEBUI_SECRET_KEY: required for JWT session signing. Move to SOPS in Phase 3.
#
# Boot-ordering:
#   /mnt/data is a LUKS2 btrfs mount. systemd-tmpfiles-setup runs before
#   LUKS mounts are guaranteed to be up, so we do NOT use tmpfiles.rules here.
#   Instead, ExecStartPre (with + prefix = runs as root) creates the directory
#   after mnt-data.mount is satisfied via after/requires ordering.
#
# Ports:
#   3000 — HTTP, bound to 127.0.0.1 (Caddy terminates TLS in Phase 3)
#
# Volumes:
#   /mnt/data/open-webui  →  /app/backend/data
{
  lib,
  pkgs,
  ...
}: {
  virtualisation.oci-containers.containers.open-webui = {
    image = "ghcr.io/open-webui/open-webui:main";

    # Host network: container reaches Ollama on 127.0.0.1:11434 directly.
    # Security: port 3000 is bound to 127.0.0.1 inside the container,
    # so it's only reachable via Caddy proxy — not directly from LAN.
    extraOptions = ["--network=host"];

    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      OLLAMA_API_KEY = "";
      HOST = "127.0.0.1";
      PORT = "3000";
      # TODO Phase 3: replace with sops secret
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
    # Hard-require the data disk — without it the bind mount silently
    # creates an empty dir on the root fs and data is lost.
    after = ["mnt-data.mount" "ollama.service"];
    requires = ["mnt-data.mount"];
    # Soft dep on Ollama: Open-WebUI starts even if Ollama is down,
    # it just shows a connection error in the UI until Ollama comes up.
    wants = ["ollama.service"];

    serviceConfig = {
      # + prefix: runs as root regardless of service User=, so mkdir
      # succeeds on the encrypted mount before the container starts.
      # This is the same pattern proven to work in ollama.nix.
      ExecStartPre = [
        "+${pkgs.coreutils}/bin/mkdir -p /mnt/data/open-webui"
        "+${pkgs.coreutils}/bin/chown root:root /mnt/data/open-webui"
        "+${pkgs.coreutils}/bin/chmod 0750 /mnt/data/open-webui"
      ];
    };
  };
}
