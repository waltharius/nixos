# hosts/servers/altair/configuration.nix
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
#   nix run github:nix-community/disko -- --mode disko /tmp/nixos/hosts/servers/altair/disko.nix
#   nixos-install --flake /tmp/nixos#altair --no-root-password

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Hardware: initrd, kernel modules, IOMMU, disk layout
    ./hardware-configuration.nix

    # Base bare-metal server profile:
    # static IP, SSH, firewall, SOPS, Atuin, Nix settings, CUDA caches
    ../../../modules/servers/base-baremetal.nix

    # -------------------------------------------------------------------------
    # Phase 2+ modules — uncomment when ready:
    # -------------------------------------------------------------------------
    # Security hardening (port knocking, fail2ban, auditd)
    # ../../../modules/servers/security/hardening.nix

    # NVIDIA drivers + CUDA
    # ../../../modules/servers/nvidia.nix

    # Tailscale overlay network
    # ../../../modules/servers/network/tailscale.nix

    # Yggdrasil self-sovereign overlay (fallback)
    # ../../../modules/servers/network/yggdrasil.nix

    # Incus container/VM host
    # ../../../modules/servers/incus/default.nix

    # Prometheus + node-exporter
    # ../../../modules/servers/monitoring/prometheus.nix

    # Grafana (Tailscale/Yggdrasil access only)
    # ../../../modules/servers/monitoring/grafana.nix

    # Corsair PSU metrics (via corsair-psu kernel module)
    # ../../../modules/servers/monitoring/psu-monitor.nix
  ];

  # ---------------------------------------------------------------------------
  # Identity
  # ---------------------------------------------------------------------------
  networking.hostName = "altair";

  # ---------------------------------------------------------------------------
  # System state version
  # Set ONCE at install time. NEVER change (controls stateful service defaults).
  # Does NOT prevent package updates — only affects stateful migration defaults.
  # ---------------------------------------------------------------------------
  system.stateVersion = "25.11";

  # ---------------------------------------------------------------------------
  # Host-specific allowUnfree (NVIDIA drivers, CUDA)
  # ---------------------------------------------------------------------------
  nixpkgs.config.allowUnfree = true;
}
