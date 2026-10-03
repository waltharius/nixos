# ASUS RT-AX92U: office-asus and parter-asus

Two ASUS RT-AX92U Wi-Fi routers, both in access point mode (pfSense
routes and serves DHCP).

| | office-asus | parter-asus |
| --- | --- | --- |
| Address | 192.168.50.220 | 192.168.50.221 |
| Role | "AiMesh Router in AP mode" (Administration -> Operation Mode) | its web UI redirects to .220, so probably an AiMesh node of office-asus (not verified) |
| USB stick | yes, ext4, mounted at `/tmp/mnt/usb` | none |
| Entware, node_exporter | yes | no (to do, below) |
| Monitoring | ping, node_exporter (`monitoring.nodeExternal`) | ping |

## Firmware

gnuton's port of Asuswrt-Merlin, `3004.388.9_2-gnuton2` (built 2025-07-31),
CPU aarch64. Login user in the web UI and over SSH: `horacjusz`.

## Administration -> System

- Persistent JFFS2 partition: "Enable JFFS custom scripts and configs" =
  Yes (needed for `/jffs/scripts/*`; JFFS is 63 MB, `/dev/mtdblock9`).
- Service: Enable SSH = LAN only, SSH port 1024, port forwarding No,
  password login Yes (can be switched off now that keys work), idle
  timeout 20 min.
- HTTPS LAN port 8443 (router's own certificate, valid until 2044).

SSH aliases `office-asus` and `parter-asus` (port 1024, user horacjusz,
key `tabby`) come from `hosts/devices/*.nix` through the generated
`~/.ssh/config.d/devices`.

## SSH key (2026-10-03)

The public key `~/.ssh/id_ed25519_tabby.pub` of azazel is in the
"Authorized Keys" field (Administration -> System -> Service), which the
firmware keeps in the nvram variable `sshd_authkeys`, so it survives
reboots. office-asus got it through the web UI. parter-asus's web UI
redirects to office-asus, so it was set over SSH (one password login):

```sh
ssh office-asus 'nvram get sshd_authkeys | cut -c1-40'   # shows the key: the variable is right
ssh parter-asus "nvram set sshd_authkeys='$(cat ~/.ssh/id_ed25519_tabby.pub)'; nvram commit; service restart_sshd"
```

Check that the key, not a reused connection, logs you in. The ssh
configuration keeps connections open for 9 minutes (`ControlMaster auto`,
`ControlPersist 9m`), so a second login after a password login never asks
again:

```sh
ssh -o ControlMaster=no -o ControlPath=none parter-asus true && echo key-works
```

Not verified: whether AiMesh synchronisation from office-asus overwrites
parter-asus's keys. If the key disappears there, set it on office-asus
and see whether it arrives.

## Entware and node_exporter on office-asus

Entware lives on the USB stick in `/tmp/mnt/usb/entware`, linked to
`/tmp/opt` (so `/opt/bin`, `/opt/etc/init.d`). node_exporter is an
Entware package with the init script `/opt/etc/init.d/S99node_exporter`,
listening on port 9100. Set up in September 2025; it has survived the
reboots since.

To fill in: the package name (`opkg list-installed | grep -i node`) and
how Entware was installed (presumably with `amtm`, Merlin's terminal
menu).

Two scripts in `/jffs/scripts` (both executable) start it:

`/jffs/scripts/post-mount`, run by the firmware after mounting a USB
volume (`$1` is the mount point):

```sh
#!/bin/sh
# Merlin: $1 to ścieżka do świeżo zamontowanego wolumenu (np. /tmp/mnt/usb)
BASE="${1:-/tmp/mnt/usb}"
if [ -d "$BASE/entware" ]; then
  # Ustaw /tmp/opt -> Entware na USB
  ln -nsf "$BASE/entware" /tmp/opt
  # PATH dla opkg i initów Entware
  export PATH=/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin
  # Napraw find w rc.unslung, jeśli /opt/bin/find nie istnieje
  if [ -x /bin/find ] && [ ! -x /opt/bin/find ]; then
    sed -i '1,/^ACTION/{s#^ACTION=.*#FIND=$([ -x /opt/bin/find ] && echo /opt/bin/find || echo /bin/find)\nACTION=$1#}' /opt/etc/init.d/rc.unslung 2>/dev/null
    sed -i 's#/opt/bin/find#$FIND#g' /opt/etc/init.d/rc.unslung 2>/dev/null
  fi
  # Start całego Entware (S* z init.d)
  [ -x /opt/etc/init.d/rc.unslung ] && /opt/etc/init.d/rc.unslung start
  # Upewnij się, że node_exporter jest uruchomiony
  [ -x /opt/etc/init.d/S99node_exporter ] && /opt/etc/init.d/S99node_exporter start
fi
```

`/jffs/scripts/services-start`, run when the router's services start:

```sh
#!/bin/sh
ln -nsf /tmp/mnt/usb/entware /tmp/opt 2>/dev/null
export PATH=/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin
[ -x /opt/etc/init.d/rc.unslung ] && /opt/etc/init.d/rc.unslung start
[ -x /opt/etc/init.d/S99node_exporter ] && /opt/etc/init.d/S99node_exporter start
```

Check from azazel: `curl -s http://192.168.50.220:9100/metrics | head -3`.

## Monitoring notes

- Alerts that do not apply to these routers are excluded in
  `modules/servers/monitoring/alert-rules.nix`: the root filesystem is a
  read-only ubifs image (FilesystemReadOnly), and the firmware's NTP
  client does not report the kernel's synchronisation status
  (ClockNotSynchronised checks the clock against Prometheus instead).
- Per-client Wi-Fi statistics (signal, rates) are not collected yet
  (idea: a script around `wl` for node_exporter's textfile collector;
  BACKLOG.md).

## To do: node_exporter on parter-asus

1. Plug in a small USB stick, format it ext4 (label as on office-asus).
2. Install Entware onto it the same way as on office-asus (see "To fill
   in" above) and the same node_exporter package.
3. Copy `post-mount` and `services-start` from office-asus to
   `/jffs/scripts/` and make them executable (`chmod +x`).
4. Check `curl -s http://192.168.50.221:9100/metrics | head -3`, then set
   `monitoring.nodeExternal = true` in `hosts/devices/parter-asus.nix`
   and deploy the monitoring server.
