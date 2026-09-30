# users/nixadm/account.nix
#
# System account of nixadm: administration and deployment of servers and
# virtual machines. Imported on every host where hosts/machines/<host>.nix lists
# nixadm. SSH and sudo policy for servers stays in modules/servers/users.nix.
{...}: {
  users.users.nixadm = {
    isNormalUser = true;
    description = "NixOS Administrator";
    extraGroups = ["wheel"]; # Enable sudo

    # SSH key authentication only
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDNK9DIORkZzPOOya7WW3LpeaYYMCTtfC33/uz9fLupV JuiceSSH"
    ];
  };
}
