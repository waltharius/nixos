# hosts/physical/altair/configuration.nix
#
# Main NixOS configuration for altair.
# Board:  ASUS ProArt X870E-CREATOR WIFI
# CPU:    AMD Ryzen 9 7900
# RAM:    64 GB DDR5
# GPUs:   2× Gigabyte RTX 3090 TURBO 24G
# Role:   Primary homelab server — Incus host, LLM inference, Immich, RAG
#
# Stage 1 (current): bare-metal NixOS, LUKS2 passphrase-only.
# Phase 2+ modules are listed but commented out — uncomment as each
# phase is completed. This makes the progression explicit and auditable.
#
# Reinstall procedure (from live USB):
#   git clone https://github.com/waltharius/nixos /tmp/nixos
#   read -rs PASS; echo -n "$PASS" > /tmp/disk-password
#   sudo nix --experimental-features "nix-command flakes" \
#     run github:nix-community/disko/latest#disko-install -- \
#     --flake /tmp/nixos#altair \
#     --write-efi-boot-entries \
#     --disk main /dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_25503L800955 \
#     --disk data /dev/disk/by-id/ata-TOSHIBA_HDWG51EUZSVA_8562A02HFQ6H
{
  lib,
  pkgs,
  ...
}: let
  gpu-burn-sm86 = pkgs.gpu-burn.overrideAttrs (old: {
    # RTX 3090 = Ampere = compute_86
    makeFlags = (old.makeFlags or []) ++ ["COMPUTE=86"];
  });

  dcgmNoCheck = pkgs.dcgm.overrideAttrs (old: {
    doCheck = false; # skip flaky CTest suite
  });
in {
  imports = [
    ./hardware-configuration.nix
    ../../../modules/servers/security/hardening.nix
    ../../../modules/servers/base-baremetal.nix
    ../../../modules/servers/monitoring/default.nix
    ../../../modules/servers/nvidia.nix
    ../../../modules/servers/incus/default.nix

    # AI / LLM stack — Phase 1
    ../../../modules/servers/ai/ollama.nix

    # AI / LLM stack — Phase 2
    ../../../modules/servers/ai/podman.nix
    ../../../modules/servers/ai/open-webui.nix
    ../../../modules/servers/ai/searxng.nix

    # Reverse proxy — Phase 3
    ../../../modules/servers/caddy.nix

    # -------------------------------------------------------------------------
    # Phase 4+ modules — uncomment when ready:
    # -------------------------------------------------------------------------
    # ../../../modules/servers/network/tailscale.nix
    # ../../../modules/servers/network/yggdrasil.nix
    # ../../../modules/servers/monitoring/prometheus.nix
    # ../../../modules/servers/monitoring/grafana.nix
    # ../../../modules/servers/monitoring/psu-monitor.nix
    # Cloudflare Tunnel config goes here in Phase 4
  ];

  environment.systemPackages = with pkgs; [
    # nvidia related packages
    gpu-burn-sm86 # VRAM + compute stress test
    ocl-icd # OpenCL ICD loader
    clinfo # OpenCL device info
    dcgmNoCheck # NVIDIA Data Center GPU Manager (includes dcgmi)
    nvtopPackages.nvidia
    (python3.withPackages (ps: [ps.torch]))
    openssl
    tree
    ethtool
  ];

  systemd.services.nvidia-dcgm = {
    description = "NVIDIA DCGM host engine";
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${dcgmNoCheck}/bin/nv-hostengine -n"; # foreground mode
      Restart = "on-failure";
    };
  };

  # Watchdog for Marvell AQC113 (enp11s0) — auto-recovers if PCIe link drops
  # under sustained transfer load. Activates only when the cable is connected.
  systemd.services."aqc113-watchdog" = {
    description = "Watchdog for Aquantia AQC113 enp11s0";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "10s";
      ExecStart = pkgs.writeShellScript "aqc113-watchdog" ''
        while true; do
          sleep 30
          # Only act if cable is plugged in and NIC is not UP
          if ${pkgs.iproute2}/bin/ip link show enp11s0 | grep -q "state DOWN"; then
            CARRIER=$(cat /sys/class/net/enp11s0/carrier 2>/dev/null || echo 0)
            if [ "$CARRIER" = "1" ]; then
              echo "enp11s0 carrier present but DOWN - reloading atlantic driver"
              ${pkgs.kmod}/bin/modprobe -r atlantic
              sleep 2
              ${pkgs.kmod}/bin/modprobe atlantic
            fi
          fi
          sleep 30
        done
      '';
    };
  };

  networking.hostName = "altair";
  services.atuin-auto-login.enable = lib.mkForce false;

  system.stateVersion = "25.11";

  nixpkgs.config.allowUnfree = true;
}
