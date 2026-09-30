# hosts/inventory.nix
#
# Single source of truth for every machine in the fleet.
#
# This file is plain data: no module logic lives here. It is consumed by
#   - parts/hosts.nix   -> nixosConfigurations (local `nixos-rebuild --flake`)
#   - parts/colmena.nix -> colmenaHive (remote deployment with Colmena)
#   - flake output `inventory` (`nix eval --json .#inventory`, e.g. for docs)
#
# It is validated by lib/inventory.nix on every evaluation: duplicate LAN
# addresses, addresses inside the router's DHCP pool, unknown classes and
# servers without a static address all abort the evaluation.
#
# The shape deliberately mirrors Clan's inventory (machines.<name>.tags,
# machines.<name>.deploy.targetHost, machines.<name>.description) so that a
# later migration to Clan is mostly a mechanical rename.
#
# Per-machine fields:
#   class       - "workstation" | "server" | "virtual"  (see lib/classes.nix)
#   system      - Nix system double, e.g. "x86_64-linux"
#   description - free text, shown in exported inventory
#   tags        - Colmena tags; select with `colmena apply --on @<tag>`
#   lan.ip      - static LAN address. Required for "server" and "virtual".
#                 For laptops this is only documentation of the DHCP
#                 reservation on the router (laptops roam between networks).
#   deploy      - Colmena deployment settings. Class defaults come from
#                 lib/classes.nix; anything set here overrides them.
#   users       - accounts on the machine and the program groups each one
#                 uses: users.<name>.groups = [ ... ]. The account must be
#                 defined in users/<name>/; the groups are listed in
#                 modules/groups/default.nix. The host gets the system part
#                 of every group of every user (see lib/users.nix).
#                 Servers and virtual machines must have nixadm.
{
  network.lan = {
    # First three octets of the home LAN.
    prefix = "192.168.50";
    # Dynamic DHCP pool of the router. Static addresses must stay outside it.
    dhcpPool = {
      first = 165;
      last = 199;
    };
  };

  machines = {
    # --- Workstations -------------------------------------------------------
    azazel = {
      class = "workstation";
      system = "x86_64-linux";
      description = "ThinkPad T16 Gen3 - primary workstation";
      tags = ["workstation" "laptop"];
      users.marcin.groups = [
        "gnome"
        "emacs"
        "office"
        "latex"
        "notes"
        "web"
        "comms"
        "media"
        "gaming"
        "nix-admin"
        "cli"
      ];
    };

    sukkub = {
      class = "workstation";
      system = "x86_64-linux";
      description = "ThinkPad P50 - test/POC workstation";
      tags = ["workstation" "laptop"];
      users.marcin.groups = [
        "gnome"
        "emacs"
        "office"
        "latex"
        "notes"
        "web"
        "comms"
        "media"
        "gaming"
        "nix-admin"
        "cli"
      ];
    };

    # --- Bare-metal servers -------------------------------------------------
    altair = {
      class = "server";
      system = "x86_64-linux";
      description = "ASUS ProArt X870E, Ryzen 9 7900, 64 GB DDR5, 2x RTX 3090";
      tags = ["server" "baremetal" "gpu" "llm"];
      lan.ip = "192.168.50.150";
      users.nixadm.groups = ["cli"];
    };

    # --- Virtual machines / containers -------------------------------------
    cloud-apps = {
      class = "virtual";
      system = "x86_64-linux";
      description = "Proxmox LXC - Nextcloud, MariaDB, Syncthing";
      tags = ["prod" "lxc" "cloud"];
      lan.ip = "192.168.50.8";
      users.nixadm.groups = ["cli"];
    };
  };
}
