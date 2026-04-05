# modules/servers/ai/ollama.nix
#
# Ollama LLM inference server — dual RTX 3090 (48 GB VRAM total).
#
# Design decisions:
#   - Runs on the HOST (not in a container) for direct GPU access.
#   - Listens on 0.0.0.0:11434 so Podman containers can reach it.
#   - LAN access (enp10s0 / 192.168.50.x) is blocked by firewall — only
#     containers on incusbr0 (10.0.0.x), Podman bridge, and localhost may
#     query Ollama directly. Open-WebUI proxies all user requests.
#   - CUDA binary cache must be active before first deploy (see base-baremetal.nix).
#   - Models stored on /mnt/data (LUKS2 btrfs) — not on the NVMe boot disk.
#
# GPU tensor split:
#   Two identical RTX 3090 24 GB → 0.5,0.5 splits layers evenly across both.
#   For models that fit in one GPU (<=24 GB), Ollama picks automatically.
#
# Firewall:
#   Port 11434 allowed on:
#     lo        — localhost (curl tests, same-host tools)
#     incusbr0  — Incus containers (10.0.0.x)
#     podman1   — Podman netavark bridge (Open-WebUI, ~10.88.0.x)
#     cni-podman0 — Podman CNI bridge (fallback name on older setups)
#   Port 11434 BLOCKED on enp10s0 (LAN) — direct API access not allowed.
#
# Systemd hardening notes:
#   - DynamicUser=true (NixOS default) is incompatible with homes on external
#     mounts — systemd can't chown paths outside its control. We declare a
#     real persistent user instead.
#   - PrivateDevices/PrivateNetwork/PrivateTmp/PrivateUsers are all forced false
#     because CUDA requires direct GPU device access and host network binding.
#   - TMPDIR/OLLAMA_TMPDIR redirect CUDA blob extraction away from /tmp
#     (ProtectSystem=strict makes /tmp read-only inside the service namespace).
{
  lib,
  pkgs,
  ...
}: {
  # ---------------------------------------------------------------------------
  # Persistent ollama user — required because DynamicUser=true is incompatible
  # with a home directory on an external encrypted mount (/mnt/data).
  # ---------------------------------------------------------------------------
  users.users.ollama = {
    isSystemUser = true;
    group        = "ollama";
    home         = "/mnt/data/ollama";
    extraGroups  = [ "render" "video" ];
  };
  users.groups.ollama = {};

  # ---------------------------------------------------------------------------
  # Ollama service
  # ---------------------------------------------------------------------------
  services.ollama = {
    enable = true;

    # Listen on all interfaces — firewall below restricts actual access.
    host = "0.0.0.0";
    port = 11434;

    # Store models on the data disk, not on the 2 TB NVMe.
    home = "/mnt/data/ollama";

    # Accelerate with CUDA (both RTX 3090s).
    # cudaSupport = true is set globally in nvidia.nix.
    acceleration = "cuda";

    environmentVariables = {
      # Both GPUs visible to CUDA.
      CUDA_VISIBLE_DEVICES     = "0,1";
      OLLAMA_GPU_OVERHEAD      = "0";

      # Keep models loaded in VRAM indefinitely (no idle unload).
      OLLAMA_KEEP_ALIVE        = "-1";

      # Allow loading up to 2 models simultaneously (one per GPU).
      OLLAMA_MAX_LOADED_MODELS = "2";

      # Process up to 2 requests in parallel.
      OLLAMA_NUM_PARALLEL      = "2";

      # Flash attention — faster, less VRAM for long contexts on Ampere.
      OLLAMA_FLASH_ATTENTION   = "1";

      # Force the models directory explicitly.
      # Without this, Ollama appends /.ollama/models to HOME.
      OLLAMA_MODELS            = "/mnt/data/ollama/models";

      # Redirect CUDA runner blob extraction away from /tmp.
      # ProtectSystem=strict (systemd default) makes /tmp read-only inside
      # the service namespace — CUDA fails to write its temp .bin files there.
      TMPDIR                   = "/mnt/data/ollama/tmp";
      OLLAMA_TMPDIR            = "/mnt/data/ollama/tmp";
    };
  };

  # ---------------------------------------------------------------------------
  # systemd service overrides
  # ---------------------------------------------------------------------------
  systemd.services.ollama = {
    # Must start after the LUKS2 data disk is mounted.
    after    = [ "mnt-data.mount" ];
    requires = [ "mnt-data.mount" ];

    serviceConfig = {
      Restart        = "on-failure";
      RestartSec     = "10s";
      # Reduce OOM kill priority — let kernel kill other processes first.
      OOMScoreAdjust = 500;

      # Override NixOS module defaults that break CUDA and GPU access.
      PrivateNetwork = lib.mkForce false;
      PrivateUsers   = lib.mkForce false;
      PrivateTmp     = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      ProtectHome    = lib.mkForce false;

      # Replace DynamicUser with our persistent user declared above.
      DynamicUser    = lib.mkForce false;
      User           = lib.mkForce "ollama";
      Group          = lib.mkForce "ollama";

      # Create required directories before service starts.
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /mnt/data/ollama/models"
        "${pkgs.coreutils}/bin/mkdir -p /mnt/data/ollama/tmp"
      ];
    };
  };

  # Pre-create directories with correct ownership on every boot activation.
  systemd.tmpfiles.rules = [
    "d /mnt/data/ollama        0750 ollama ollama -"
    "d /mnt/data/ollama/models 0750 ollama ollama -"
    "d /mnt/data/ollama/tmp    0750 ollama ollama -"
  ];

  # ---------------------------------------------------------------------------
  # Firewall — Ollama port 11434 access control
  #
  # ALLOW:  lo          (localhost)
  # ALLOW:  incusbr0    (Incus containers, 10.0.0.x)
  # ALLOW:  podman1     (Podman netavark bridge — Open-WebUI container)
  # ALLOW:  cni-podman0 (Podman CNI bridge — fallback for older Podman)
  # BLOCK:  enp10s0     (LAN — direct API access blocked)
  # ---------------------------------------------------------------------------
  networking.firewall.interfaces."incusbr0".allowedTCPPorts   = [ 11434 ];
  networking.firewall.interfaces."podman1".allowedTCPPorts     = [ 11434 ];
  networking.firewall.interfaces."cni-podman0".allowedTCPPorts = [ 11434 ];
}
