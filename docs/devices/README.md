# Manual configuration of devices

Devices without NixOS (`hosts/devices/`) are partly configured by hand:
in a web UI, over SSH, with a package manager the repository does not
drive. Nothing in the repository would rebuild that configuration after a
reset or a replacement, so it is written down here, one file per device or
group of identical devices.

Rules:

- Write it down when you do it, with the commands as typed and where in a
  web UI a setting lives.
- No secrets: name the user, never the password or key (passwords live in
  the password manager, keys in `~/.ssh`).
- What `nix run .#fleet` installs (agents, fixes) is described by its
  playbooks in `ansible/`; mention it here only with the task to run.
- Mark what was not verified as such.

| File | Devices |
| --- | --- |
| [asus-routers.md](asus-routers.md) | office-asus, parter-asus (ASUS RT-AX92U) |
| [pfsense.md](pfsense.md) | pfsense |
| [proxmox.md](proxmox.md) | pve |
