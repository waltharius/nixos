# hosts/devices.nix
#
# Devices that are not NixOS machines of this repository: routers, the
# Proxmox host, containers and VMs on it, Raspberry Pis, other people's
# computers. Fields are described in hosts/README.md.
#
# This file feeds
#   - the address plan: lib/inventory.nix checks every lan.ip against the
#     machines and the router's DHCP pool;
#   - ~/.ssh/config.d/devices for accounts with the nix-admin group (one
#     `Host` block per entry under `ssh`, so `ssh <TAB>` completes them);
#   - /etc/ssh/ssh_known_hosts on every NixOS host, for entries with
#     `hostKey`.
#
# Only permanent devices belong here. For a short test use
# ~/.ssh/config.d/local on your machine instead (see
# ~/.ssh/config.d/README.md).
#
# `key` names the private key: "tabby" (LAN admin key, the default),
# "gitlab", "github" or null (no IdentityFile line).
{
  # --- Network ------------------------------------------------------------
  pfsense = {
    description = "pfSense router (being replaced by OPNsense)";
    lan.ip = "192.168.50.1";
    ssh.pfsense.user = "root";
  };

  opnsense = {
    description = "OPNsense router (Dell Wyse 5070)";
    lan.ip = "192.168.50.149";
  };

  parter-asus = {
    lan.ip = "192.168.50.221";
    ssh.parter-asus = {
      user = "horacjusz";
      port = 1024;
    };
  };

  bedroom-asus = {
    lan.ip = "192.168.50.219";
    ssh.bedroom-asus = {
      user = "horacjusz";
      port = 1024;
    };
  };

  office-asus = {
    lan.ip = "192.168.50.220";
    ssh.office-asus = {
      user = "horacjusz";
      port = 1024;
    };
  };

  # --- Proxmox and its guests -----------------------------------------------
  pve = {
    description = "Proxmox VE host";
    lan.ip = "192.168.50.200";
    ssh.pve.user = "root";
  };

  check-mk = {
    description = "Checkmk (being replaced by Prometheus/Grafana)";
    lan.ip = "192.168.50.103";
    ssh.check_mk.user = "root";
  };

  ipa = {
    lan.ip = "192.168.50.250";
    ssh.ipa.user = "root";
  };

  docker = {
    lan.ip = "192.168.50.9";
    ssh.docker.user = "root";
  };

  cloudflare-ddns = {
    lan.ip = "192.168.50.10";
    ssh.cloudflare-ddns.user = "root";
  };

  caddy = {
    description = "Caddy reverse proxy (Debian, to be moved to NixOS)";
    lan.ip = "192.168.50.114";
    ssh.caddy.user = "root";
  };

  alpine-mariadb = {
    lan.ip = "192.168.50.152";
    ssh.alpine-mariadb.user = "root";
  };

  apache = {
    lan.ip = "192.168.50.151";
    ssh.apache.user = "root";
  };

  immich = {
    lan.ip = "192.168.50.100";
    ssh.immich.user = "root";
  };

  syncthing-server = {
    lan.ip = "192.168.50.95";
    ssh.syncthing-server.user = "root";
  };

  win11 = {
    description = "Windows 11 VM (rdp-win11), no SSH";
    lan.ip = "192.168.50.6";
  };

  # --- Raspberry Pi ---------------------------------------------------------
  walthpi = {
    lan.ip = "192.168.50.47";
    ssh.walthpi.user = "walthpi";
  };

  walthpi16 = {
    description = "Raspberry Pi - also runs GitLab (SSH on port 2424)";
    lan.ip = "192.168.50.46";
    ssh = {
      walthpi16.user = "walthpi";
      gitlab-host = {
        # The name the repositories use (ssh://git@gitlab.home.lan:2424/...),
        # so the pinned key below is found under it: ssh looks up
        # [gitlab.home.lan]:2424 in known_hosts.
        hostName = "gitlab.home.lan";
        user = "git";
        port = 2424;
        hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7BmOynY5MjyVY0Thyr/Uxy8X1c9ppRW6brptgDtdJR";
        key = "gitlab";
        extraOptions.PreferredAuthentications = "publickey";
      };
    };
  };

  # --- Other computers ------------------------------------------------------
  yumeko = {
    lan.ip = "192.168.50.164";
    ssh.yumeko.user = "marcin";
  };

  luna = {
    lan.ip = "192.168.50.102";
    ssh.luna.user = "marcin";
  };
}
