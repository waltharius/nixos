# Remote access (Tailscale)

How the fleet is reached from outside the home network. The Nix side is
`lib/tailscale.nix` and the `tailscale` field of `hosts/machines/<host>.nix`
(see `hosts/README.md`); pfSense and the tailnet policy are configured by
hand and described here.

## Overview

| What | Tailscale | Reached from away |
| ---- | --------- | ----------------- |
| pfSense | Tailscale package, subnet router for `192.168.50.0/24`, tag `tag:router` | - |
| marcin's laptops (azazel, sukkub, baal) | `join = "owner"`, `acceptRoutes = true` | tailnet name or LAN address |
| computers managed for others (stage 6) | `join = "tagged"` (`tag:managed`) or `"shared"` | tailnet name |
| servers, virtual machines, other LAN devices | none | LAN address, through pfSense |
| a host that publishes a service with Funnel (calibre on a Raspberry Pi) | own client, outside this repository | - |

The subnet router sits on pfSense on purpose: when pfSense is down the
home network is down anyway, so remote access adds no new point of
failure. A server as the router would add one (altair needs its LUKS
passphrase after every power loss).

Colmena deploys servers by `lan.ip` (`lib/classes.nix`); from away the
same addresses go through the subnet router, so nothing changes in the
hive. Services published to the internet use Cloudflare Tunnel by default.

## pfSense (manual)

Set up on pfSense CE on 2026-10-01; verified from a laptop on a phone
hotspot (LAN reachable, `home.lan` names resolve).

1. Back up the configuration: Diagnostics > Backup & Restore > Download
   configuration as XML.
2. The tailnet policy must name `tag:router` in `tagOwners` before a
   tagged key can be created: save the policy below first.
3. Admin console, Settings > Keys: generate an auth key, not reusable, not
   ephemeral, with the tag `tag:router`. Tagged devices have key expiry
   disabled by default.
4. System > Package Manager > Available Packages: install `Tailscale`.
5. VPN > Tailscale > Authentication: paste the key. VPN > Tailscale >
   Settings: Enable; Accept DNS off; Advertise Exit Node **off**; Accept
   Subnet Routes off; Advertised Routes `192.168.50.0/24`. Save.
6. The route is approved by `autoApprovers` in the policy; check it in the
   admin console (Machines > pfsense > Edit route settings).
7. **Firewall > Rules > Tailscale** (the interface group): add a rule.
   Without it pfSense drops everything that arrives from the tailnet,
   because an interface without a pass rule blocks inbound traffic.

   | Field | Value |
   | ----- | ----- |
   | Action | Pass |
   | Interface | Tailscale |
   | Address Family | IPv4 |
   | Protocol | Any |
   | Source | Network `100.64.0.0/10` |
   | Destination | LAN subnets |
   | Description | tailnet to home LAN (tailnet policy filters first) |

8. Check from away (e.g. a phone hotspot) on a laptop with
   `acceptRoutes`: `ip route get 192.168.50.150` shows `tailscale0`,
   `ping 192.168.50.150`, `ssh altair`, `resolvectl query altair.home.lan`.

Not needed here:

- An access list for `100.64.0.0/10` in the DNS Resolver: `home.lan`
  names resolved from the tailnet before the firewall rule existed.
  Tailscale apparently hands split-DNS queries for a subnet-routed
  nameserver to the subnet router itself rather than sending them through
  the routed path (not verified in the Tailscale source).
- Outbound NAT: LAN hosts see the laptop's 100.x address and answer it
  through pfSense, their default gateway. A LAN service whose own firewall
  accepts only `192.168.50.0/24` would reject that address; then either
  allow `100.64.0.0/10` in the service or add hybrid outbound NAT on LAN
  for the source `100.64.0.0/10`.

If a rule on the Tailscale group does not match, check
`ifconfig tailscale0 | grep groups` (Diagnostics > Command Prompt) for the
group `Tailscale`: pfSense Plus 26.07 has a reported bug where the
interface is missing from the group (redmine.pfsense.org issue 17034).

### Relayed instead of direct connections

`tailscale status` showing `relay "waw"` for pfsense means the traffic
goes through a Tailscale DERP relay: it works, with more latency and less
throughput. Tailscale notes that devices behind pfSense often end up
relayed, and that inbound UDP 41641 open on a device's public address
allows a direct connection whenever one is possible
([firewalls](https://tailscale.com/docs/integrations/firewalls),
[connection types](https://tailscale.com/kb/1257/connection-types)).
Here pfSense's WAN address is private (192.168.11.x): the provider's
roof antenna does NAT in front of it and cannot be configured, so no port
can be forwarded to pfSense. A WAN rule passing UDP 41641 to the WAN
address was tried on 2026-10-01: it never matched a packet, and from a
phone hotspot `tailscale ping pfsense` still reported "direct connection
not established". Mobile networks usually put clients behind carrier NAT
as well; with NAT on both ends that cannot be configured, the relay is
what remains. From other networks (a friend's Wi-Fi, an office) a direct
connection may still work: check with `tailscale ping pfsense`.

The way out is a node with a public address that both ends can reach, for
example a Tailscale peer relay on the planned VPS (BACKLOG.md).

Moving from pfSense to OPNsense means repeating this on OPNsense.

## Tailnet policy (admin console, Access controls)

Edit the policy file in the **JSON editor** of Access controls, not in the
visual rule editor (its "Capability" field is for application
capabilities, not for a policy). Save the current file before editing.

Tailscale's default policy lets every device reach every other one (the
grant `{"src": ["*"], "dst": ["*"], "ip": ["*"]}`). The policy below
allows only marcin's own devices to start connections; tagged devices
(pfSense, managed computers) can only answer. It keeps two parts of the
default file: `nodeAttrs` with the `funnel` attribute (or calibre stops
being published) and the Tailscale SSH rule (unused while no host runs
`tailscale up --ssh`).

`group:admin` must hold the login exactly as the Users page of the admin
console shows it (e.g. `name@gmail.com`, or `name@github` for a GitHub
login), in `groups` and in `tests`. The `tests` make saving fail when the
policy does not do what it should.

```hujson
{
  "groups": {
    // marcin's Tailscale login, as shown on the Users page.
    "group:admin": ["you@example.com"],
  },

  "tagOwners": {
    "tag:router":  ["group:admin"],
    "tag:managed": ["group:admin"],
  },

  // pfSense advertises the home LAN; approve it without a click.
  "autoApprovers": {
    "routes": {
      "192.168.50.0/24": ["tag:router"],
    },
  },

  "grants": [
    // marcin's devices: every tailnet device and the home LAN.
    {"src": ["group:admin"], "dst": ["*", "192.168.50.0/24"], "ip": ["*"]},

    // Managed computers (stage 6): only the Atuin server. Fill in its
    // address and port before enabling.
    // {"src": ["tag:managed"], "dst": ["192.168.50.X"], "ip": ["tcp:PORT"]},
  ],

  // Tailscale SSH (from the default policy; unused while no host runs
  // `tailscale up --ssh`).
  "ssh": [
    {
      "action": "check",
      "src":    ["autogroup:member"],
      "dst":    ["autogroup:self"],
      "users":  ["autogroup:nonroot", "root"],
    },
  ],

  // Funnel for members' own devices (calibre on a Raspberry Pi). Narrow it
  // to a tag once that device is tagged (BACKLOG.md).
  "nodeAttrs": [
    {
      "target": ["autogroup:member"],
      "attr":   ["funnel"],
    },
  ],

  "tests": [
    // marcin reaches the LAN (altair's SSH) through the subnet router.
    {"src": "you@example.com", "accept": ["192.168.50.150:22"]},
    // Managed computers do not.
    {"src": "tag:managed", "deny": ["192.168.50.150:22"]},
  ],
}
```

Devices without a grant as `src` cannot start any connection. That is the
point for `tag:managed`, and it needs no extra grant for `tag:router`: the
subnet router only forwards connections that the policy allows from their
source. A device that is still untagged and owned by marcin counts as
`group:admin`, including the calibre Raspberry Pi published with Funnel
(BACKLOG.md: tag it).

## DNS (admin console, DNS)

- MagicDNS: on.
- Nameservers: add `192.168.50.1`, restricted to the domain `home.lan`
  (split DNS). `home.lan` names then resolve away from home too, through
  the subnet router.
- "Override local DNS": off. Only `home.lan` and tailnet names go to
  Tailscale; everything else uses the network the laptop is on.

`owner` machines accept this DNS and run systemd-resolved. Without a DNS
manager Tailscale rewrites `/etc/resolv.conf` and fights NetworkManager
over it ([Tailscale: Linux DNS](https://tailscale.com/docs/reference/linux-dns)).
`tagged` and `shared` machines ignore tailnet DNS.

## Workstations

| `join` | Logs in as | Routes | DNS | First login |
| ------ | ---------- | ------ | --- | ----------- |
| `owner` | marcin (operator: `tailscale` without sudo) | `acceptRoutes` | MagicDNS, split DNS | one-off key from install-host, or `tailscale-join` |
| `tagged` | the tags of the key | none | own network | one-off tagged key from install-host |
| `shared` | its owner, in their own tailnet | none | own network | the owner logs in; then shares the machine with marcin |

- Client settings (`--accept-routes`, `--accept-dns`, `--operator`) are
  applied with `tailscale set` on every boot (`tailscaled-set.service`),
  so manual changes do not survive a reboot.
- `tailscale-join` runs `tailscale up` with every flag from the
  repository, plus anything passed to it (e.g. `--auth-key=file:...`).
  Use it instead of a bare `tailscale up`, which refuses to change
  settings unless all non-default flags are repeated.
- Internet traffic does not go through Tailscale (no exit node), so
  websites see the normal address of the network the laptop is on.
- Key expiry: devices logged in as a user (not tagged) have to log in
  again when their node key expires. For marcin's own laptops it can be
  disabled per machine in the admin console (Machines > ... > Disable key
  expiry).

### Home LAN at home and away

With `acceptRoutes` the laptop knows the route `192.168.50.0/24` through
the subnet router. On Linux Tailscale installs it with policy routing rules
(priorities 5200-5500) that win over the normal LAN route, so at home the
traffic to the LAN would take a detour through the tunnel and pfSense
([Tailscale: LAN traffic with overlapping subnet routes](https://tailscale.com/docs/reference/troubleshooting/network-configuration/lan-traffic-overlapping-subnets)).

The home Wi-Fi profiles (`modules/system/wifi.nix`) therefore carry the
rule `priority 2500 to 192.168.50.0/24 table 254`: while a home profile is
up, the LAN is looked up in the main table first. Away from home the rule
is gone and the LAN goes through the tunnel. Tailscale's own workaround is
the same rule set globally, which on a laptop could send traffic meant for
the home LAN into a foreign network; tying it to the home profiles avoids
that.

On a foreign network that also uses `192.168.50.0/24` the tunnel wins:
the home LAN is reachable, the devices of that foreign network are not.

Checks:

```sh
ip rule                       # at home: a rule with priority 2500
ip route get 192.168.50.1     # at home: dev wlp...; away: dev tailscale0
tailscale status
resolvectl status tailscale0  # DNS servers and the home.lan domain
```

## Login server (Headscale later)

`tailscale.loginServer` in `hosts/fleet.nix` is `null` (Tailscale's control
server). Pointing it to Headscale changes the flags of `tailscale-join`
only; machines that are already logged in move after `tailscale-join` is
run on each of them. `shared` machines stay in their owner's tailnet.
Constraints of Headscale are listed in `BACKLOG.md`.

## Troubleshooting

| Symptom | Look at |
| ------- | ------- |
| not in the tailnet | `tailscale status`, `journalctl -u tailscaled -u tailscaled-set -u tailscale-join-once -b` |
| first-boot join failed | `/var/lib/tailscale-join/auth-key` still exists; the key may have expired: delete it and run `tailscale-join` |
| LAN unreachable from away | the route is approved in the admin console, the laptop has `acceptRoutes`, `ip route get 192.168.50.150` shows tailscale0, pfSense is online in `tailscale status`, the pass rule on Firewall > Rules > Tailscale exists (Status > System Logs > Firewall shows blocks) |
| slow, `relay "..."` in `tailscale status` | relayed through DERP; see "Relayed instead of direct connections" |
| LAN slow at home | `ip rule` lacks priority 2500: reconnect the home Wi-Fi profile (`nmcli connection up <profile>`) |
| DNS | `resolvectl status`, `resolvectl query <name>.home.lan` |
