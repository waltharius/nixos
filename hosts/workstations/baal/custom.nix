# hosts/workstations/baal/custom.nix
#
# What baal has that other workstations do not: hardware support and
# host-level features. Everything every workstation gets comes from the
# class in lib/classes.nix; programs come from the groups of the host's
# users in hosts/machines/baal.nix.
{...}: {
  imports = [
    # e.g. ../../../modules/laptop/thunderbolt.nix
    ./writing.nix
    ./hibernate.nix
  ];

  # sops-nix with the host key derived from the SSH host key
  # (sops.keySource = "ssh-host-key" in hosts/machines/baal.nix).
  services.secrets.enable = true;
}
