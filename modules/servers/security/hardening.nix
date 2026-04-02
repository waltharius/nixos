# modules/servers/security/hardening.nix
# Base system hardening for all altair services.
# Does NOT manage per-service firewall rules — those live in each service module.
{lib, ...}: {
  # --- Firewall base policy ---
  networking.firewall = {
    enable = true;
    # Default deny inbound. Services open their own ports in their own modules.
    allowedTCPPorts = [];
    allowedUDPPorts = [];
    # Log refused packets (useful early on, can be disabled later)
    logRefusedConnections = true;
    logRefusedPackets = false; # too noisy
  };

  # Enable the full nftables module as the firewall backend.
  # networking.firewall.* options all continue to work unchanged.
  # Required for Incus: both host firewall and Incus NAT must use
  # the same kernel subsystem (nftables). Without this, Incus writes
  # its NAT rules to nftables while the host firewall uses iptables,
  # creating two separate rulesets that cannot see each other.
  networking.nftables.enable = true;

  # --- SSH hardening ---
  services.openssh = {
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
      LoginGraceTime = 30;
      # Restrict to key types with strong security
      PubkeyAcceptedKeyTypes = "ssh-ed25519,ecdsa-sha2-nistp256,rsa-sha2-512,rsa-sha2-256";
    };
    # Only listen on LAN interface - not on Incus bridge
    listenAddresses = [
      {
        addr = "192.168.50.150";
        port = 22;
      } # adjust to altair's LAN IP
    ];
  };

  # Firewall rule for SSH - colocated with the SSH config above
  # This is an exception: SSH is infrastructure, not a service module,
  # so its firewall rule lives here in hardening.nix
  networking.firewall.interfaces."enp10s0".allowedTCPPorts = [22];

  # --- Kernel hardening (sysctl) ---
  boot.kernel.sysctl = {
    # Network hardening
    "net.ipv4.conf.all.rp_filter" = 1; # reverse path filtering
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0; # ignore ICMP redirects
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1; # ignore broadcast pings
    "net.ipv4.tcp_syncookies" = 1; # SYN flood protection
    # Memory protection
    "kernel.dmesg_restrict" = 1; # non-root can't read dmesg
    "kernel.kptr_restrict" = 2; # hide kernel pointers
    "kernel.unprivileged_bpf_disabled" = 1; # restrict eBPF
    "net.core.bpf_jit_harden" = 2;
  };

  # --- Fail2ban ---
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h"; # 1 week max ban
    };
    jails = {
      sshd = {
        settings = {
          enabled = true;
          filter = "sshd";
          maxretry = 3;
          bantime = "24h";
        };
      };
    };
  };

  # --- Disable unnecessary services ---
  services.avahi.enable = lib.mkDefault false;
  services.printing.enable = lib.mkDefault false;

  # --- Audit log ---
  security.auditd.enable = true;
  security.audit.enable = true;
  security.audit.rules = [
    "-a exit,always -F arch=b64 -S execve" # log all exec calls
    "-w /etc/passwd -p wa -k identity" # watch passwd changes
    "-w /etc/shadow -p wa -k identity"
    "-w /etc/sudoers -p wa -k sudoers"
  ];
}
