# hosts/templates/

Files copied by `nix run .#new-host` into a new host's directory. `@NAME@`
placeholders are replaced by the script:

| Placeholder        | Value                                   |
| ------------------ | --------------------------------------- |
| `@HOST@`           | host name                               |
| `@DESCRIPTION@`    | description from the inventory          |
| `@SYSTEM@`         | Nix system, e.g. `x86_64-linux`         |
| `@STATE_VERSION@`  | NixOS release of the pinned nixpkgs     |
| `@DISK@`           | install disk (disko templates only)     |
| `@EXTRA_IMPORTS@`  | extra imports of `custom.nix`, e.g. `./writing.nix` |

`<class>/` holds the host files of a class, `disko/` the disk layouts a
workstation or server can choose from. `writing.nix` is added to a
workstation that uses `disko/btrfs-luks-writing.nix`. These files are not loaded by the
flake; edit them to change what future hosts start with.
