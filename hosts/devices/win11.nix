# hosts/devices/win11.nix - fields are described in hosts/README.md
#
# Not monitored: the VM runs only while it is being used.
{
  description = "Windows 11 VM (rdp-win11), no SSH";
  lan.ip = "192.168.50.6";
}
