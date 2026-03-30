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

    # -------------------------------------------------------------------------
    # Phase 2+ modules — uncomment when ready:
    # -------------------------------------------------------------------------
    # ../../../modules/servers/network/tailscale.nix
    # ../../../modules/servers/network/yggdrasil.nix
    # ../../../modules/servers/incus/default.nix
    # ../../../modules/servers/monitoring/prometheus.nix
    # ../../../modules/servers/monitoring/grafana.nix
    # ../../../modules/servers/monitoring/psu-monitor.nix
  ];

  environment.systemPackages = with pkgs; [
    # nvidia related packages
    gpu-burn-sm86 # VRAM + compute stress test
    ocl-icd # OpenCL ICD loader
    clinfo # OpenCL device info
    dcgm # NVIDIA Data Center GPU Manager (includes dcgmi)
    nvtopPackages.nvidia
    (python3.withPackages (ps: [ps.torch]))
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

  networking.hostName = "altair";
  services.atuin-auto-login.enable = lib.mkForce false;

  system.stateVersion = "25.11";

  nixpkgs.config.allowUnfree = true;
}
