# Adding a host

`nix run .#new-host` (script: `scripts/new-host.sh`) registers a new NixOS
machine. Run it on azazel from the repository root; it needs the admin age
key and a clean `.sops.yaml` and `secrets/`.

## What it asks

Host name, class (`workstation`, `server`, `virtual`), description, Colmena
tags, LAN address (required for servers and virtual machines, suggested as
the first free address outside the DHCP pool), the network interface
(servers), accounts and the program groups of each account, for
workstations how the machine joins the tailnet (`owner`, `tagged`,
`shared` or none; see `docs/REMOTE-ACCESS.md`), and for workstations and
servers the disk layout and install disk.

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

Disk layouts (`hosts/templates/disko/`): `btrfs`, `btrfs-luks` (LUKS2,
passphrase at every boot) and `btrfs-luks-writing` (as `btrfs-luks`, plus
marcin's writing subvolumes Documents, notes and syncthing with snapshots,
as on azazel; the host also gets `writing.nix`).

## After the script

1. Review with `git diff --cached`, run `nix flake check`, commit.
2. Adjust `hosts/<class dir>/<host>/disko.nix` (disk by id, swap size) and
   `custom.nix` (hardware modules) as needed.
3. Install the machine (next section). Never deploy a host while its
   `hardware-configuration.nix` is still the placeholder.

## Installing (`nix run .#install-host`)

Script: `scripts/install-host.sh`, using
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere).

1. Write the NixOS minimal installer ISO to a USB stick and boot the
   machine from it (UEFI).
2. On the installer console: connect to the network (`nmtui` for Wi-Fi),
   set a temporary root password (`sudo passwd root`), note the address
   (`ip -br a`) and the disk (`ls -l /dev/disk/by-id/`).
3. On azazel: put the disk id into `disko.nix` (`device =
   "/dev/disk/by-id/..."`) if `new-host` got a different one, commit, and
   copy your key to the installer: `ssh-copy-id root@<address>`.
4. `nix run .#install-host -- <host> root@<address>` (on azazel, like
   every command here except step 2). It asks for the LUKS passphrase (if
   the layout encrypts), an initial password for every account on the
   host and, if the host has a `tailscale` entry, a one-off auth key
   (admin console, Settings > Keys; required with tags for `tagged`,
   optional for `owner`), shows the disk that will be erased and asks for
   confirmation.
   nixos-anywhere then partitions the disk, generates
   `hardware-configuration.nix` on the target (`nixos-generate-config
   --no-filesystems`; disko describes the file systems) and installs the
   system with the stored SSH host key. The script sets the passwords in
   the installed system, leaves the Tailscale key in
   `/var/lib/tailscale-join/auth-key` (the unit `tailscale-join-once` joins
   with it at the first boot and deletes it) and reboots the machine.
   Without a key, run `tailscale-join` on the host after the first boot
   and open the login URL it prints.
5. Unlock the disk at the console, log in, run the checks below, commit
   `hardware-configuration.nix` and push it before the host rebuilds from
   a clone (a clone with the placeholder builds an unbootable system).
6. `ssh-keygen -R <installer address>`: the installer's temporary host key
   is in `~/.ssh/known_hosts` and would clash if the host later gets that
   address.

Passwords are not in the repository, not even as hashes: accounts are
mutable, the initial password stays until `passwd` changes it, and only
its yescrypt hash travels to the target. A host installed without a
password (before install-host asked for one) is fixed from the installer:
`cryptsetup open /dev/disk/by-partlabel/disk-main-root cryptroot`, mount
the subvolumes `@` at /mnt and `@nix` at /mnt/nix, then
`nixos-enter --root /mnt -c 'passwd <user>'`.

### What the output means

Everything runs on azazel; the target only executes what nixos-anywhere
sends over SSH, its own screen stays at the installer prompt until the
reboot.

| Output | Where / what |
| ------ | ------------ |
| `Warning: Identity file …/nixos-anywhere not accessible` | nixos-anywhere tries its temporary key before creating it; harmless |
| `Uploading install SSH keys` … `All keys were skipped` | the key from `ssh-copy-id` already works; harmless |
| `Gathering machine facts`, `Pseudo-terminal will not be allocated` | target, over SSH: architecture, installer or not (no kexec on the installer) |
| `Generating hardware-configuration.nix` | target scans its hardware, the file is written into the repository on azazel |
| `Git tree … is dirty` | expected: the hardware file just changed and the flake uses the new content |
| `building …` | azazel builds the system |
| `Uploading /run/user/…/disk.key to /tmp/secret.key` | the LUKS passphrase, for formatting only |
| `copying path … from 'https://cache.nixos.org'` | the **target** downloads what it needs from the binary cache itself (nixos-anywhere `--substitute-on-destination`); one line per path because there is no terminal for a progress bar. Over Wi-Fi this takes long (baal: about 1.5 h) |
| `Formatting hard drive with disko` and the `+ …` trace | target: partitions, LUKS, btrfs subvolumes, swap file |
| `Uploading the system closure` | the rest of the system, again mostly downloaded by the target |
| `Copying extra files` | the stored SSH host key |
| `Installing NixOS`, `setting up secrets…` | sops-nix decrypts with the age key derived from the SSH host key; `Cannot read ssh key '/etc/ssh/ssh_host_rsa_key'` is harmless (only an ed25519 key is provided) |
| `installation finished!` | then install-host sets the passwords and reboots |

The same package name and version can appear two or three times with
different hashes: the hash covers every build input, and the system mixes
nixpkgs stable and unstable (`pkgs-unstable`) and build variants. `nix-store
--query --referrers <path>` on the host shows what needs a given copy.

## Checks after the first boot

| Check | Command |
| ----- | ------- |
| nothing failed | `systemctl --failed`, `journalctl -b -p err` |
| boot entries | `bootctl status` |
| mounts and swap | `findmnt -t btrfs,vfat`, `swapon --show` |
| writing subvolumes owned by the user | `ls -ld ~/Documents ~/notes ~/syncthing` |
| snapshots configured | `sudo snapper list-configs` |
| secrets decrypted | `sudo ls -l /run/secrets/`, `ls -l ~/.ssh/` |
| git keys and pinned host keys | `ssh -T git@github.com`, `ssh -T git@gitlab.com` |
| home Wi-Fi address | `ip -br a` |
| SSH from azazel | `ssh <host>` (no question about the host key) |
| disk usage | `df -h /`, `sudo btrfs filesystem usage /` |
| sleep | close the lid, open, check `journalctl -b -p warning` |
| tailnet | `tailscale status`; `systemctl status tailscale-join-once` (the key file is gone after a successful join) |
| home LAN stays off the tunnel (`acceptRoutes`) | at home: `ip rule` lists priority 2500, `ip route get 192.168.50.1` shows the Wi-Fi interface |

The installer runs from the USB stick, so nixos-anywhere does not need
kexec (kexec is only used when the target runs some other Linux).
Afterwards the host has its final SSH host key, which is pinned in every
host's `/etc/ssh/ssh_known_hosts`; SSH to the installer itself asks to
trust its temporary key.

## Undo before committing

```sh
git restore --staged hosts/machines/<host>.nix hosts/<class dir>/<host> secrets .sops.yaml
rm -r hosts/machines/<host>.nix hosts/<class dir>/<host> secrets/hosts/<host>
git checkout -- .sops.yaml secrets
```
