# secrets/

Encrypted secrets managed with [sops](https://github.com/getsops/sops) and
decrypted on the hosts by [sops-nix](https://github.com/Mic92/sops-nix).
Only encrypted files are committed; never commit decrypted copies or
private keys (`.gitignore` blocks the usual names, but check `git status`).

## Who can decrypt what

`.sops.yaml` is **generated** (`lib/secrets.nix`), never edited by hand.
The audience of a file is:

1. every admin key in `hosts/fleet.nix` (`sops.admins`) - always;
2. every host whose configuration uses the file, i.e. it is the `sopsFile`
   of a `sops.secrets.<n>` of the system or of a Home Manager user on that
   host;
3. every host that lists the file in `sops.extraSecrets` of its machine
   file (for a secret a host must read before any module uses it).

Everything else below `secrets/` (host SSH keys in `secrets/hosts/`, new
files nothing uses yet) is encrypted for the admin keys only.

sops encrypts a whole file for all of its recipients. Put secrets with
different audiences into different files: a host that can decrypt a file
can read every value in it (`sops -d` as root), not only the values its
modules use.

## Everyday tasks

All commands run from the repository root on azazel (the admin key is in
`~/.config/sops/age/keys.txt`).

| Task | Commands |
| ---- | -------- |
| Edit a secret | `sops secrets/<file>` |
| New secret file | `sops secrets/<file>` (created for the admin only), `git add secrets/<file>`, reference it in a module, then `nix run .#sops-config` |
| A host starts or stops using a file | `nix run .#sops-config` |
| Check everything | `nix flake check` (checks `sops-config` and `sops-recipients`) |

`nix run .#sops-config` writes `.sops.yaml` and runs `sops updatekeys` on
every secret file, so each file ends up encrypted for exactly its current
audience. Commit `.sops.yaml` together with the changed secret files. The
flake only sees files known to git, so `git add` new files first.

`nix flake check` fails when

- `.sops.yaml` differs from what the configuration implies (`sops-config`),
- an encrypted file is missing a key its rule names, or is still encrypted
  for a key that should no longer read it (`sops-recipients`).

Removing a key from a file does not protect values that key could already
read: they are in git history and possibly on the host. Rotate the values
themselves when that matters.

## Host keys

Each machine file has `sops.ageKey` (public) and `sops.keySource`:

| `keySource` | Private key on the host | Used by |
| ----------- | ----------------------- | ------- |
| `key-file` | `/var/lib/sops-nix/key.txt`, created by hand | hosts installed before refactor stage 2 (azazel, sukkub, altair, cloud-apps) |
| `ssh-host-key` | derived from `/etc/ssh/ssh_host_ed25519_key` | hosts added with `nix run .#new-host` |

azazel's host key is the admin key. For `ssh-host-key` hosts the SSH host
private key is kept in `secrets/hosts/<host>/ssh_host_ed25519_key`,
encrypted for the admin keys only, so a reinstalled host keeps its identity
and its access to secrets.

## Adding an admin key

Add it to `sops.admins` in `hosts/fleet.nix`, then `nix run .#sops-config`
on a machine that already has an admin key.
