# hosts/devices/luna.nix - fields are described in hosts/README.md
#
# Not monitored: a personal computer, not infrastructure. Managed by marcin
# for a non-technical user; Tailscale and a reinstall with NixOS are
# planned (BACKLOG.md, stage 6).
{
  description = "Family laptop (ThinkPad W540, Fedora 42 KDE), managed by marcin";
  lan.ip = "192.168.50.102";
  ssh.luna.user = "marcin";
}
