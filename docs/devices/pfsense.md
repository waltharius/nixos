# pfSense

pfSense 2.7.2 Community Edition on 192.168.50.1 (2.8.1 hangs on this
box). Router, firewall, DHCP, Tailscale subnet router; being replaced by
OPNsense (BACKLOG.md).

## UPS (Services -> UPS)

APC Back-UPS 850 (BE850G2-GR) on USB; the NUT package monitors it and
tells the connected machines to shut down.

- UPS Settings: UPS Type "Local USB", UPS Name `apcups`, notifications on,
  driver `usbhid` with extra arguments `offdelay=260`, `ondelay=900`,
  `lowbatt=90`.
- upsmon.conf additions: `MONITOR apcups@localhost 1 admin <password>
  master`, `MINSUPPLIES 1`, `SHUTDOWNCMD "/sbin/shutdown -p +1"`,
  `NOTIFYCMD /usr/local/bin/upssched`, `POLLFREQ 5`, `POLLFREQALERT 5`,
  `HOSTSYNC 200`, `DEADTIME 15`, `FINALDELAY 5`.
- upsd.conf additions: `LISTEN 0.0.0.0 3493`, `MAXAGE 15`. Proposed:
  `LISTEN 192.168.50.1 3493` (LAN only).
- NUT users: `admin` (SET, all instant commands, upsmon master) and
  `monuser` (upsmon slave). Passwords in the password manager. The
  `admin` password was visible in a screenshot on 2026-10-03; change it
  in both places (users and the MONITOR line).

The monitoring server reads the UPS from upsd without a login
(`monitoring.ups = "apcups"` in `hosts/devices/pfsense.nix`, job `nut`).
Check: `nix shell nixpkgs#nut -c upsc apcups@192.168.50.1`.

## node_exporter (System -> Package Manager)

Package `node_exporter` 0.18.1_3 (node_exporter 1.6.1), installed
2026-10-03. Settings (Services -> node_exporter): enabled, interface LAN,
port 9100, the default collectors (boottime, cpu, exec, filesystem,
loadavg, meminfo, netdev, textfile, time), extra flags `--log.level=warn`.
The uname and os collectors, which fail with 'cannot allocate memory' on
2.7.x (https://redmine.pfsense.org/issues/14452), are not in that set.
Scraped as `monitoring.nodeExternal = true`.

The unbound chroot's read-only nullfs mounts (`/var/unbound/...`) are
excluded from FilesystemReadOnly.
