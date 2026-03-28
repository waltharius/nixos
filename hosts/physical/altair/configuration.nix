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
#   nix run github:nix-community/disko -- --mode disko /tmp/nixos/hosts/physical/altair/disko.nix
#   nixos-install --flake /tmp/nixos#altair --no-root-password

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../../modules/servers/base-baremetal.nix

    # -------------------------------------------------------------------------
    # Phase 2+ modules — uncomment when ready:
    # -------------------------------------------------------------------------
    # ../../../modules/servers/security/hardening.nix
    # ../../../modules/servers/nvidia.nix
    # ../../../modules/servers/network/tailscale.nix
    # ../../../modules/servers/network/yggdrasil.nix
    # ../../../modules/servers/incus/default.nix
    # ../../../modules/servers/monitoring/prometheus.nix
    # ../../../modules/servers/monitoring/grafana.nix
    # ../../../modules/servers/monitoring/psu-monitor.nix
  ];

  networking.hostName = "altair";

  system.stateVersion = "25.11";

  nixpkgs.config.allowUnfree = true;
}
