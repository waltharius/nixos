# modules/servers/ai/ollama.nix
#
# Ollama LLM inference server — dual RTX 3090 (48 GB VRAM total).
#
# Design decisions:
#   - Runs on the HOST (not in a container) for direct GPU access.
#   - Listens on 0.0.0.0:11434 so Podman containers can reach it.
#   - LAN access (enp10s0 / 192.168.50.x) is blocked by firewall — only
#     containers on incusbr0 (10.0.0.x), Podman bridges, and localhost may
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
#     lo          — localhost
#     incusbr0    — Incus containers (10.0.0.x)
#     podman0     — Podman bridge CONFIRMED active (10.88.0.1/16)
#     podman1     — Podman netavark bridge (alternate name)
#     cni-podman0 — Podman CNI bridge (older Podman fallback)
#   Port 11434 BLOCKED on enp10s0 (LAN).
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
    acceleration = "cuda";

    environmentVariables = {
      CUDA_VISIBLE_DEVICES     = "0,1";
      OLLAMA_GPU_OVERHEAD      = "0";
      OLLAMA_KEEP_ALIVE        = "-1";
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_NUM_PARALLEL      = "2";
      OLLAMA_FLASH_ATTENTION   = "1";
      OLLAMA_MODELS            = "/mnt/data/ollama/models";
      TMPDIR                   = "/mnt/data/ollama/tmp";
      OLLAMA_TMPDIR            = "/mnt/data/ollama/tmp";
    };
  };

  # ---------------------------------------------------------------------------
  # systemd service overrides
  # ---------------------------------------------------------------------------
  systemd.services.ollama = {
    after    = [ "mnt-data.mount" ];
    requires = [ "mnt-data.mount" ];

    serviceConfig = {
      Restart        = "on-failure";
      RestartSec     = "10s";
      OOMScoreAdjust = 500;

      PrivateNetwork = lib.mkForce false;
      PrivateUsers   = lib.mkForce false;
      PrivateTmp     = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      ProtectHome    = lib.mkForce false;

      DynamicUser    = lib.mkForce false;
      User           = lib.mkForce "ollama";
      Group          = lib.mkForce "ollama";

      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /mnt/data/ollama/models"
        "${pkgs.coreutils}/bin/mkdir -p /mnt/data/ollama/tmp"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/data/ollama        0750 ollama ollama -"
    "d /mnt/data/ollama/models 0750 ollama ollama -"
    "d /mnt/data/ollama/tmp    0750 ollama ollama -"
  ];

  # ---------------------------------------------------------------------------
  # Firewall — Ollama port 11434 access control
  #
  # podman0 is the CONFIRMED active bridge (10.88.0.1/16 per ip addr output).
  # Keep podman1 and cni-podman0 entries so config survives Podman upgrades
  # that may rename the bridge.
  # ---------------------------------------------------------------------------
  networking.firewall.interfaces."incusbr0".allowedTCPPorts   = [ 11434 ];
  networking.firewall.interfaces."podman0".allowedTCPPorts     = [ 11434 ];
  networking.firewall.interfaces."podman1".allowedTCPPorts     = [ 11434 ];
  networking.firewall.interfaces."cni-podman0".allowedTCPPorts = [ 11434 ];
}
