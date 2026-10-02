# SSH

How SSH is configured across the fleet. The day-to-day guide for the host
lists is `~/.ssh/config.d/README.md` on an admin workstation (source:
`users/marcin/home/ssh-config.d-README.md`).

## Keys of marcin

| Key | File | Hosts that get it |
| --- | ---- | ----------------- |
| GitHub, GitLab (`id_ed25519_github`, `id_ed25519_gitlab`) | `secrets/users/marcin/git.yaml` | marcin has `emacs` or `nix-admin` |
| LAN admin key (`id_ed25519_tabby`) and the private host list | `secrets/users/marcin/admin.yaml` | marcin has `nix-admin` |

They are decrypted by the system sops-nix with the host key
(`users/marcin/secrets.nix`) and placed in `~/.ssh/`. A laptop without
`nix-admin` (e.g. a writing laptop) can reach git forges but cannot log
into servers.

## Host lists (`~/.ssh/config.d/`)

`~/.ssh/config` includes, in this order: `local` (yours, never managed),
`hosts` (encrypted), `fleet` (generated from `hosts/machines/`), `devices`
(generated from `hosts/devices/*.nix`). ssh takes the first value it finds,
so earlier files win. The generated texts come from `lib/ssh.nix`.

## Known hosts

`/etc/ssh/ssh_known_hosts` on every NixOS host is generated
(`programs.ssh.knownHosts`, `lib/ssh.nix`) from

- `ssh.hostKey` in `hosts/machines/<host>.nix` (and `hostKey` of
  `ssh.aliases`),
- `hostKey` of SSH aliases in `hosts/devices/*.nix`,
- the published ed25519 keys of github.com and gitlab.com.

Hosts with a pinned key are verified without trust on first use, also by
Colmena. Entries in your own `~/.ssh/known_hosts` still work as before.

Adding the key of an existing host: on the host run
`cat /etc/ssh/ssh_host_ed25519_key.pub`, put the line (without the comment)
into `ssh.hostKey`, rebuild. Read it on the host itself or over an SSH
connection you already trust, not with `ssh-keyscan`, which trusts whatever
answers.

## Rotating pinned host keys

When github.com or gitlab.com rotate their host key, ssh stops with
`REMOTE HOST IDENTIFICATION HAS CHANGED` for that host.

1. Check the announcement and the new fingerprint on the official page:
   - GitHub: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
   - GitLab.com: https://docs.gitlab.com/user/gitlab_com/#ssh-host-keys-fingerprints
2. Get the new public key and compare its fingerprint with the page:
   ```sh
   ssh-keyscan -t ed25519 github.com > /tmp/github.pub
   ssh-keygen -lf /tmp/github.pub   # must match the published SHA256
   ```
   The fingerprint check is what makes `ssh-keyscan` safe here.
3. Replace the key and the fingerprint comment in `external` in
   `lib/ssh.nix`, rebuild (or deploy) every host.
4. Remove a stale copy from your own file if ssh still complains:
   `ssh-keygen -R github.com`.

For a fleet host (reinstall without the stored key, new SSH host key):
update `ssh.hostKey` in its machine file and deploy. Hosts added with
`new-host` keep their key across reinstalls, because the private key is
stored encrypted in `secrets/hosts/<host>/`.
