# modules/servers/base-baremetal.nix
#
# Base configuration for bare-metal NixOS servers.
# Analogous to base-lxc.nix but for physical machines:
#   - Full systemd (not container-limited)
#   - Static IP via systemd-networkd
#   - sandbox = true (kernel namespaces available on bare metal)
#   - CUDA binary cache pre-configured (for NVIDIA GPU servers)
#   - Atuin shell history sync (same as LXC servers)
#   - SOPS secrets via existing services.secrets pattern
#
# Import this in every bare-metal server configuration.nix
# alongside hardware-configuration.nix and disko.nix.
{
  host,
  pkgs,
  ...
}: {
  imports = [
    ../system/secrets.nix
    ../system/certificates.nix
    ./users.nix
    ../system/atuin-login.nix
    ./encryption/initrd-ssh.nix
  ];

  # ---------------------------------------------------------------------------
  # SOPS secrets — same pattern as base-lxc.nix
  # /var/lib/sops-nix/key.txt must be generated on first boot:
  #   nix-shell -p age --run "age-keygen -o /var/lib/sops-nix/key.txt"
  # Then add the public key to .sops.yaml and re-encrypt secrets.
  # ---------------------------------------------------------------------------
  services.secrets = {
    enable = true;
    enableAtuin = true;
  };

  # ---------------------------------------------------------------------------
  # Atuin auto-login — shared server account (mirrors base-lxc.nix)
  # ---------------------------------------------------------------------------
  services.atuin-auto-login = {
    enable = true;
    users = ["nixadm"];
    username = "admin";
  };

  # ---------------------------------------------------------------------------
  # Nix settings
  # ---------------------------------------------------------------------------
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];

    # Trust nixadm and wheel for remote Colmena deployments
    trusted-users = ["nixadm" "root" "@wheel"];

    # sandbox = true on bare metal (unlike LXC where kernel namespaces
    # are restricted). Improves build isolation and security.
    sandbox = true;

    # ---------------------------------------------------------------------------
    # CUDA binary caches — CRITICAL: must be present BEFORE first
    # nixos-rebuild with NVIDIA drivers. Without these, NixOS compiles
    # CUDA from source which takes 6-12 hours.
    #
    # cuda-maintainers.cachix.org was deleted (2026-09-11); the NixOS CUDA
    # team's cache is now cache.nixos-cuda.org (see wiki.nixos.org/wiki/CUDA).
    # New substituters only take effect after activation, so a build that
    # runs before this config is live must pass them via --option.
    # ---------------------------------------------------------------------------
    substituters = [
      "https://cache.nixos.org"
      "https://cache.nixos-cuda.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    keep-outputs = false;
    keep-derivations = false;
  };

  # ---------------------------------------------------------------------------
  # Networking — static IP via systemd-networkd
  # NIC: enp10s0 (Intel I226-V 2.5G, MAC: 30:c5:99:5b:ec:97)
  # IP:  192.168.50.150/24 (static DHCP reservation in pfSense)
  #
  # ⚠️  CRITICAL macvlan note
  #     When Incus uses enp10s0 as a macvlan parent (lanbr0), the HOST
  #     cannot communicate directly with macvlan containers. Only other
  #     LAN devices or containers on incusbr0 (10.0.0.x) can reach them
  #     from the host. Design host→container comms via incusbr0.
  # ---------------------------------------------------------------------------
  networking.useDHCP = false;
  networking.useNetworkd = true;

  # LinkLocalAddressing = "no" is required when enp10s0 will become a
  # macvlan parent. Setting it now avoids a rebuild later.
  systemd.network = {
    enable = true;
    networks = {
      "10-lan" = {
        # Interface and address come from hosts/machines/<host>.nix.
        matchConfig.Name = host.lan.interface;
        networkConfig = {
          Address = "${host.lan.ip}/24";
          Gateway = "192.168.50.1"; # pfSense
          DNS = ["192.168.50.1"]; # pfSense DNS
          DHCP = "no";
          LinkLocalAddressing = "no"; # Required for future Incus macvlan parent
          IPv6AcceptRA = false;
        };
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Domain and DNS
  # ---------------------------------------------------------------------------
  networking.domain = "home.lan";
  networking.search = ["home.lan"];
  networking.nameservers = ["192.168.50.1"];

  # nixpkgs 26.05 converted services.resolved to RFC42-style settings.
  # Only FallbackDNS needs to be explicit; the module derives the rest:
  #   DNS        <- networking.nameservers (default)
  #   Domains    <- networking.search      (default)
  #   DNSSEC     =  false                  (module default)
  #   DNSOverTLS =  false                  (module default)
  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = ["9.9.9.9"]; # Quad9 fallback
  };

  # ---------------------------------------------------------------------------
  # Boot loader — systemd-boot (UEFI only)
  # ---------------------------------------------------------------------------
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10; # Keep 10 generations for rollback
      # editor = false prevents kernel param editing at physical console.
      # Security trade-off: slightly harder to recover from bad boot params,
      # but prevents physical-access kernel injection attacks.
      editor = false;
    };
    efi = {
      canTouchEfiVariables = true; # Required for systemd-boot EFI entry management
      efiSysMountPoint = "/boot"; # Must match disko.nix ESP mountpoint
    };
  };

  # ---------------------------------------------------------------------------
  # SSH — base config (hardening added in Phase 2 via security module)
  # ---------------------------------------------------------------------------
  services.openssh = {
    enable = true;
    ports = [22];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
    };
  };

  # ---------------------------------------------------------------------------
  # Locale and timezone
  # ---------------------------------------------------------------------------
  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";

  # ---------------------------------------------------------------------------
  # Essential server packages
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # Core
    vim
    git
    curl
    wget
    htop
    btop
    python3

    # Network diagnostics
    bind # dig, nslookup
    inetutils # ping, traceroute

    # Storage / LUKS inspection
    cryptsetup
    btrfs-progs
    lsof

    # Hardware inspection
    pciutils # lspci
    usbutils # lsusb
    lm_sensors # sensors
    nvme-cli # nvme smart-log

    # Modern replacements
    eza # Better ls
    zoxide # Smart cd

    # Secrets tooling
    sops
    age
  ];

  # ---------------------------------------------------------------------------
  # Automatic garbage collection
  # ---------------------------------------------------------------------------
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.optimise = {
    automatic = true;
    dates = ["weekly"];
  };
}
