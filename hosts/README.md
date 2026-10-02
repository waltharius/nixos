# hosts/

The inventory: every machine of the fleet and the settings shared by all
of them. It is plain data, loaded and validated by `lib/inventory.nix` on
every evaluation (`nix flake check`, `nixos-rebuild`, `colmena`).

| Path                         | Contents                                         |
| ---------------------------- | ------------------------------------------------ |
| `fleet.nix`                  | fleet-wide settings: LAN prefix, DHCP pool, admin age keys, Tailscale login server, monitoring server and alert e-mail |
| `machines/<host>.nix`        | one NixOS machine; the file name is the host name |
| `devices/<name>.nix`         | one device that is not a NixOS machine; the file name is the device name |
| `websites.nix`               | web pages probed by the monitoring (`docs/MONITORING.md`) |
| `templates/`                 | files for new hosts (`nix run .#new-host`)       |
| `workstations/<host>/`       | host files of class `workstation`                |
| `physical/<host>/`           | host files of class `server`                     |
| `virtual/<host>/`            | host files of class `virtual`                    |

Every `*.nix` file in `machines/` and `devices/` is loaded automatically. New machines
are added with `nix run .#new-host` (see `docs/NEW-HOST.md`).

The inventory is exported as JSON for external tooling:
`nix eval --json .#inventory`.

## Machine fields (`machines/<host>.nix`)

| Field         | Required            | Meaning |
| ------------- | ------------------- | ------- |
| `class`       | yes                 | `workstation`, `server` or `virtual` (see `lib/classes.nix`) |
| `system`      | yes                 | Nix system, e.g. `x86_64-linux` |
| `description` | no                  | free text, shown in the exported inventory |
| `tags`        | no                  | Colmena tags; select with `colmena apply --on @<tag>` |
| `lan.ip`      | server, virtual     | static LAN address. Workstations: the static address on the home Wi-Fi profiles (`modules/system/wifi.nix`); without it they use DHCP at home as everywhere else |
| `lan.interface` | server            | network interface the static address is set on (`modules/servers/base-baremetal.nix`) |
| `deploy`      | no                  | Colmena deployment settings; override the class defaults from `lib/classes.nix` |
| `users`       | yes                 | accounts on the machine and the program groups each one uses: `users.<n>.groups = [ ... ]`. The account must exist in `users/<n>/account.nix`, the groups in `modules/groups/default.nix`. The host gets the system part of every group of every user (see `lib/users.nix`). Servers and virtual machines must have `nixadm` |
| `sops.ageKey` | yes                 | age public key of the host (see `secrets/README.md`) |
| `sops.keySource` | yes              | `key-file` (`/var/lib/sops-nix/key.txt`, hosts from before stage 2) or `ssh-host-key` (derived from the SSH host key) |
| `sops.extraSecrets` | no            | secret files the host must decrypt although no module uses them yet, e.g. `["secrets/foo.yaml"]` |
| `ssh.hostKey` | no                  | public SSH host key (`ssh-ed25519 AAAA...`); pinned in `/etc/ssh/ssh_known_hosts` of every host |
| `ssh.aliases.<alias>` | no          | extra SSH names of the machine, e.g. the initrd SSH of a LUKS server; fields as for device aliases below |
| `tailscale`   | no                  | the machine runs the Tailscale client (`lib/tailscale.nix`, `docs/REMOTE-ACCESS.md`). Without it: no Tailscale; servers and virtual machines are reached through the subnet router on pfSense |
| `tailscale.join` | with `tailscale` | `owner` (marcin's own computer, logged in as marcin; MagicDNS and split DNS), `tagged` (managed for someone else, joined with a one-off tagged key) or `shared` (in its owner's own tailnet, shared with marcin). `owner` and `shared` only on workstations |
| `tailscale.acceptRoutes` | no       | `owner` only: use the home LAN route of the subnet router; at home the home Wi-Fi profiles keep LAN traffic off the tunnel (`modules/system/wifi.nix`). Default `false` |
| `tailscale.tags` | `tagged`         | tags the auth key carries, e.g. `["tag:managed"]` |
| `tailscale.operator` | no           | `owner` only: account that may run `tailscale` without sudo; default `marcin`, must have an account on the machine |

Monitoring needs no field: machines of class `server` and `virtual` are
monitored automatically, workstations are not (`lib/monitoring.nix`,
`docs/MONITORING.md`).

## Device fields (`devices/<name>.nix`)

One file per device, named after it (`[a-z][a-z0-9-]*`). Start a new one by
copying a similar file. Each file starts with
`# hosts/devices/<name>.nix - fields are described in hosts/README.md`.

| Field | Meaning |
| ----- | ------- |
| `description` | free text |
| `lan.ip` | address; checked like machine addresses (in the LAN, outside the DHCP pool, not used twice) |
| `ssh.<alias>` | one SSH `Host` block in `~/.ssh/config.d/devices` of admin accounts |
| `ssh.<alias>.user`, `.port` | `User`, `Port` |
| `ssh.<alias>.hostName` | `HostName` when it is not `lan.ip` (e.g. a DNS name) |
| `ssh.<alias>.key` | `"tabby"` (default), `"gitlab"`, `"github"` or `null`: which `IdentityFile` |
| `ssh.<alias>.hostKey` | public host key, pinned in `/etc/ssh/ssh_known_hosts` |
| `ssh.<alias>.extraOptions` | other ssh_config options, e.g. `{PreferredAuthentications = "publickey";}` |
| `monitoring.ping` | `true`: the monitoring server pings the device; HostDown alert when it stops answering. Needs `lan.ip`. Leave it out for devices that are often switched off |
| `monitoring.pve` | `true`: a Proxmox VE host; the pve exporter on the monitoring server reads its API (host, VMs, containers, storage) at `https://<lan.ip>:8006`. Needs `lan.ip`, the read-only token from `modules/servers/monitoring/pve.nix` and a pveproxy certificate that covers the address |

Temporary SSH hosts do not belong here: use `~/.ssh/config.d/local` (see
`docs/SSH.md`).

The shape deliberately mirrors Clan's inventory (`machines.<n>.tags`,
`machines.<n>.deploy.targetHost`, `machines.<n>.description`) so that a
later migration to Clan stays mostly a mechanical rename.

## Fleet fields for monitoring (`fleet.nix`)

| Field | Meaning |
| ----- | ------- |
| `monitoring.server` | machine (class `server`) that runs Prometheus, Alertmanager and Grafana |
| `monitoring.mail.to` | recipient of alert e-mails |
| `monitoring.mail.from` | sender address of alert e-mails |

## Validation

Evaluation aborts with a list of all problems when a machine file name is
not a valid host name, a class is unknown, `system` is missing, a server or
virtual machine has no `lan.ip` or no `nixadm`, a server has no
`lan.interface`, an address (machine or device) is outside the LAN, inside
the router's DHCP pool or used twice, an SSH alias is defined twice, a
user or group does not exist, a `sops` field is missing or malformed, or
a `tailscale` entry breaks the rules in the table above (unknown field or
`join`, a field that does not fit the `join`, a malformed tag, a
`loginServer` in `fleet.nix` that is not null or an `https://` URL), the
`monitoring` settings in `fleet.nix` are missing or name no server, a
device's `monitoring` has an unknown field or `ping`/`pve` without `lan.ip`, or a
page in `websites.nix` has an invalid name or no `http(s)://` URL.
