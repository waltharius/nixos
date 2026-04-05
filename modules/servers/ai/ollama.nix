# modules/servers/ai/ollama.nix
#
# Ollama LLM inference server — dual RTX 3090 (48 GB VRAM total).
#
# Design decisions:
#   - Runs on the HOST (not in a container) for direct GPU access.
#   - Listens on 0.0.0.0:11434 so Podman containers (10.0.0.x) can reach it.
#   - LAN access (enp10s0 / 192.168.50.x) is blocked by firewall — only
#     containers on incusbr0 (10.0.0.x) and localhost may query Ollama directly.
#     Open-WebUI container proxies all user requests.
#   - CUDA binary cache must be active before first deploy (see base-baremetal.nix).
#   - Models stored on /mnt/data (LUKS2 btrfs) — not on the NVMe boot disk.
#
# GPU tensor split:
#   Two identical RTX 3090 24 GB → 0.5,0.5 splits layers evenly across both.
#   For models that fit in one GPU (<=24 GB), Ollama picks automatically.
#
# Firewall:
#   Port 11434 is NOT added to networking.firewall.allowedTCPPorts (global).
#   Only explicitly allowed on incusbr0 (containers) and lo (localhost).
#   enp10s0 (LAN) stays blocked — users access via Open-WebUI only.
{
  lib,
  pkgs,
  ...
}: {
  # Declare a real persistent ollama user.
  # DynamicUser=true (set by the NixOS module) is incompatible with
  # homes on external mounts — systemd can't chown paths it doesn't control.
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    home = "/mnt/data/ollama";
    # Give GPU access
    extraGroups = ["render" "video"];
  };
  users.groups.ollama = {};

  services.ollama = {
    enable = true;

    # Listen on all interfaces — firewall below restricts actual access.
    host = "0.0.0.0";
    port = 11434;

    # Store models on the data disk, not on the 2 TB NVMe.
    # /mnt/data is the LUKS2 btrfs volume (unlocked at boot via Clevis/passphrase).
    home = "/mnt/data/ollama";

    # Accelerate with CUDA (both RTX 3090s).
    # nixpkgs cudaSupport = true is set globally in nvidia.nix — this just
    # ensures Ollama itself is built against CUDA.
    acceleration = "cuda";

    environmentVariables = {
      # Split tensor layers evenly across GPU 0 and GPU 1.
      # Format: "gpu0_fraction,gpu1_fraction" — must sum to 1.0.
      OLLAMA_GPU_OVERHEAD = "0";
      CUDA_VISIBLE_DEVICES = "0,1";

      # Keep models loaded in VRAM indefinitely (no idle unload).
      # Avoids 10-30s reload delay between requests.
      OLLAMA_KEEP_ALIVE = "-1";

      # Allow loading up to 2 models simultaneously (one per GPU if needed).
      OLLAMA_MAX_LOADED_MODELS = "2";

      # Increase context window limit — allows larger prompts without truncation.
      OLLAMA_NUM_PARALLEL = "2";

      # Flash attention — faster and less VRAM for long contexts on Ampere.
      OLLAMA_FLASH_ATTENTION = "1";
      # Redirects the CUDA blob extraction to a path ollama own instead of using
      # /tmp, and keeps all other systemd hardening intact.
      OLLAMA_TMPDIR = "/mnt/data/ollama/tmp";
      # Force ollama models folder
      OLLAMA_MODELS = "/mnt/data/ollama/models";
    };
  };

  # ---------------------------------------------------------------------------
  # Ensure ollama starts AFTER /mnt/data is mounted.
  # The data disk is LUKS2-encrypted and mounted by a systemd mount unit.
  # Without this ordering, ollama may start before the disk is available.
  # ---------------------------------------------------------------------------
  systemd.services.ollama = {
    after = ["mnt-data.mount"];
    requires = ["mnt-data.mount"];
    # Restart on failure — CUDA init occasionally fails on first boot.
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
      # Reduce OOM kill priority slightly — kernel should kill other things first.
      OOMScoreAdjust = 500;

      # The upstream NixOS ollama module sets these — we override with mkForce
      # because namespace isolation breaks CUDA GPU access and incusbr0 binding.
      PrivateNetwork = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      PrivateTmp = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      ProtectHome = lib.mkForce false;
      # Override DynamicUser — we manage the user ourselves above
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "ollama";
      Group = lib.mkForce "ollama";

      # Create model dirs before service starts, as the ollama user.
      # This is the correct pattern when home is on an external mount.
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
  # Firewall — Ollama port access control
  #
  # ALLOW:  lo        (localhost — same-host tools, curl tests)
  # ALLOW:  incusbr0  (10.0.0.x — Podman containers: Open-WebUI, SearXNG)
  # BLOCK:  enp10s0   (192.168.50.x LAN — users must go through Open-WebUI)
  #
  # This is intentional: raw API access from LAN is blocked.
  # Only Open-WebUI (running as a container on incusbr0) talks to Ollama.
  # ---------------------------------------------------------------------------
  networking.firewall.interfaces."incusbr0".allowedTCPPorts = [11434];
  # lo is always allowed by the NixOS firewall (not configurable per-interface).
  # enp10s0 intentionally has NO entry for 11434.
}
