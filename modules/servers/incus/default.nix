# modules/servers/incus/default.nix
#
# Incus container/VM host configuration for altair.
# Storage: btrfs pool on /mnt/data/incus (LUKS2-encrypted 14TB disk).
# Networks:
#   - incusbr0: NAT bridge (10.0.0.1/24) — default profile, host-accessible
#   - lan:      macvlan parent enp10s0   — direct LAN presence, Phase 3+
# Metrics: Prometheus scrapes 127.0.0.1:9101 (see monitoring/prometheus.nix)
#
# ⚠️  PRESEED WARNING
#     The preseed block is consumed ONCE on first `incus admin init`.
#     Changing it after Incus is already initialized has NO effect.
#     To re-apply: incus admin init --preseed < /path/to/preseed.yaml
#     or wipe /var/lib/incus/ (destroys all containers).
#
# ⚠️  MACVLAN NOTE (from base-baremetal.nix)
#     The host cannot communicate directly with containers on the lan
#     profile (macvlan limitation). Use incusbr0 (10.0.0.x) for any
#     host→container communication (Prometheus scraping, etc.).
{lib, ...}: {
  # ---------------------------------------------------------------------------
  # Core Incus service
  # ---------------------------------------------------------------------------
  virtualisation.incus = {
    enable = true;
    ui.enable = true;

    # -----------------------------------------------------------------
    # Preseed — applied ONCE on first incus admin init. See warning above.
    # -----------------------------------------------------------------
    preseed = {
      # Daemon-level config - sets global Incus behaviour
      config = {
        # Expose Prometheus metrics on loopback only.
        # prometheus.nix scrape job: targets = ["127.0.0.1:9101"]
        # Do not change this port without updating monitoring/prometheus.nix.
        "core.metrics_address" = "127.0.0.1:9101";
        "core.https_address" = "0.0.0.0:8443";
      };
      networks = [
        {
          # NAT bridge — containers get 10.0.0.x, reach internet via host NAT.
          # Default profile uses this bridge.
          # Host is reachable from containers at 10.0.0.1.
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.0.0.1/24";
            "ipv4.nat" = "true";
            "ipv6.address" = "none";
            "ipv6.nat" = "false";
          };
        }
      ];

      storage_pools = [
        {
          # Primary storage pool on the LUKS2-encrypted 14TB data disk.
          # Directory is pre-created by systemd-tmpfiles below.
          # Phase 5: add a second pool here for the M.23 NVMe scratch disk.
          name = "default";
          driver = "btrfs";
          config = {
            source = "/mnt/data/incus";
          };
        }
      ];

      profiles = [
        {
          # Default profile: NAT bridge + default storage pool.
          # All containers use this unless explicitly overridden.
          name = "default";
          devices = {
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
            eth0 = {
              name = "eth0";
              network = "incusbr0";
              type = "nic";
            };
          };
        }
        {
          # LAN profile: macvlan — containers get a real LAN IP from pfSense DHCP.
          # ⚠️  Host CANNOT reach containers on this profile directly (macvlan
          #     limitation). Only other LAN devices can reach them.
          # Usage: incus launch <image> <name> --profile lan
          # Requires: enp10s0 LinkLocalAddressing = "no" (set in base-baremetal.nix)
          name = "lan";
          devices = {
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
            eth0 = {
              name = "eth0";
              nictype = "macvlan";
              parent = "enp10s0";
              type = "nic";
            };
          };
        }
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # User access — nixadm gets incus-admin group for CLI access without sudo.
  # users.nix already sets extraGroups = ["wheel"]; NixOS merges lists.
  # ---------------------------------------------------------------------------
  users.users.nixadm.extraGroups = ["incus-admin"];

  # ---------------------------------------------------------------------------
  # Firewall
  #
  # networking.nftables.enable = true is set in hardening.nix — both host
  # firewall and Incus NAT run on the same nftables backend.
  #
  # trustedInterfaces: packets from incusbr0 bypass INPUT chain rules.
  # Required for: Prometheus scraping container exporters over 10.0.0.x,
  # DNS queries from containers to host resolver, DHCP on the bridge.
  #
  # Port 8443: Incus HTTPS API — needed for remote incus CLI / web UI.
  # Restricted to LAN interface only (enp10s0), not exposed on incusbr0.
  # ---------------------------------------------------------------------------
  networking.firewall = {
    trustedInterfaces = ["incusbr0"];
    interfaces."enp10s0".allowedTCPPorts = [8443];
  };

  # ---------------------------------------------------------------------------
  # IP forwarding — required for NAT bridge (incusbr0) to route container
  # traffic to the internet. Without this, containers have no outbound access.
  # ---------------------------------------------------------------------------
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # ---------------------------------------------------------------------------
  # Pre-create /mnt/data/incus before incus.service starts.
  # If this directory is missing when Incus initialises the btrfs pool,
  # the pool init fails and Incus records a broken state in its database.
  # Fixing that requires manual `incus admin init --preseed` or a state wipe.
  #
  # The 'L+' type creates the path as a directory if missing, idempotently.
  # Owner: root:root with 0711 — Incus manages its own permissions inside.
  # ---------------------------------------------------------------------------
  # ---------------------------------------------------------------------------
  # Service ordering — incus.service must start AFTER /mnt/data is mounted.
  # The cryptdata LUKS device and its btrfs mount are managed by systemd
  # via /etc/fstab entries generated by disko. The mount unit name is
  # derived from the mountpoint: /mnt/data → mnt-data.mount
  #
  # Without this ordering, a fast boot could start Incus before LUKS unlock
  # completes, causing the btrfs pool to fail on an empty mountpoint.
  # ---------------------------------------------------------------------------
  systemd.services.incus.after = lib.mkAfter ["mnt-data.mount"];
  systemd.services.incus.requires = ["mnt-data.mount"];
}
