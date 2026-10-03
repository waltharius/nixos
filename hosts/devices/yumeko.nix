# hosts/devices/yumeko.nix - fields are described in hosts/README.md
#
# Not monitored: a personal computer, not infrastructure. Managed by marcin
# for a non-technical user, usually switched off; Tailscale and a reinstall
# with NixOS are planned (BACKLOG.md, stage 6).
{
  description = "Family laptop, managed by marcin (usually off)";
  lan.ip = "192.168.50.164";
  ssh.yumeko.user = "marcin";
}
