# ~/.ssh/config.d/

SSH host lists, included from `~/.ssh/config` (inside `Host *`). ssh uses
the first value it finds for an option, so earlier layers win:

| Layer     | Source                                         | Managed by | Edit here? |
| --------- | ---------------------------------------------- | ---------- | ---------- |
| `local`   | this directory                                 | you        | yes        |
| `hosts`   | `secrets/users/marcin/admin.yaml` (encrypted)  | sops-nix   | no         |
| `fleet`   | `hosts/machines/*.nix` (NixOS machines)        | Nix        | no         |
| `devices` | `hosts/devices.nix` (everything else)          | Nix        | no         |

Blocks written directly in `~/.ssh/config` (github.com, gitlab.com,
gitlab.home.lan, 192.168.50.*) come before all layers.

`hosts`, `fleet` and `devices` exist only on hosts where marcin has the
`nix-admin` group. `ssh <TAB>` completes every `Host` of every layer, and
hosts in `/etc/ssh/ssh_known_hosts`.

## Where does a new host go?

- **Trying something, temporary, only this machine** -> `local`. It is
  created once and never touched again: no rebuild, nothing in git.
- **A NixOS machine of the fleet** -> `nix run .#new-host` in the nixos
  repository; it appears in `fleet` automatically.
- **A permanent device without NixOS** (router, VM, Raspberry Pi) ->
  `hosts/devices.nix`, then rebuild. Its address is also checked against
  the rest of the network.
- **Private and not for the repository** (external servers, account names)
  -> `hosts`: `sops secrets/users/marcin/admin.yaml`, key `ssh_config`.

The generated files are read-only links into /nix/store: editing them
fails instead of losing your change. To override one option of a
generated host for a while, add a block with the same name to `local`.
