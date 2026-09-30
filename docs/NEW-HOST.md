# Adding a host

`nix run .#new-host` (script: `scripts/new-host.sh`) registers a new NixOS
machine. Run it on azazel from the repository root; it needs the admin age
key and a clean `.sops.yaml` and `secrets/`.

## What it asks

Host name, class (`workstation`, `server`, `virtual`), description, Colmena
tags, LAN address (required for servers and virtual machines, suggested as
the first free address outside the DHCP pool), the network interface
(servers), accounts and the program groups of each account, and for
workstations and servers the disk layout and install disk.

## What it writes

| Path | Contents |
| ---- | -------- |
| `hosts/machines/<host>.nix` | inventory entry, age key (`keySource = "ssh-host-key"`), SSH host public key |
| `hosts/<class dir>/<host>/` | host files from `hosts/templates/<class>/`, `disko.nix` from `hosts/templates/disko/` |
| `secrets/hosts/<host>/ssh_host_ed25519_key` | the SSH host private key, sops-encrypted for the admin keys only |

Then it stages the files, runs `nix run .#sops-config` (so every secret the
new host uses is re-encrypted for it, e.g. `secrets/wifi.env` and marcin's
git keys on a workstation) and evaluates the host. Nothing is committed.
If a step fails, the files it created are removed.

The host's age key is derived from its SSH host key (`ssh-to-age`), so the
machine can decrypt its secrets as soon as it boots with that key. Because
the private SSH key is stored (encrypted) in the repository, a reinstall
keeps the host's identity: no new `known_hosts` entry, no `.sops.yaml`
change.

## After the script

1. Review with `git diff --cached`, run `nix flake check`, commit.
2. Adjust `hosts/<class dir>/<host>/disko.nix` (disk by id, swap size) and
   `custom.nix` (hardware modules) as needed.
3. Install (refactor stage 3, nixos-anywhere): the installer puts the
   stored SSH host key on the machine and replaces the placeholder
   `hardware-configuration.nix` with the hardware scan. Never deploy a host
   while the placeholder is still there.

## Undo before committing

```sh
git restore --staged hosts/machines/<host>.nix hosts/<class dir>/<host> secrets .sops.yaml
rm -r hosts/machines/<host>.nix hosts/<class dir>/<host> secrets/hosts/<host>
git checkout -- .sops.yaml secrets
```
