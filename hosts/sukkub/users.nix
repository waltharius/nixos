# hosts/sukkub/users.nix
# User assignments for sukkub laptop
{
  hostUsers = {
    marcin = {
      roles = ["regular" "maintainer"];
      desktopPreference = "gnome";
      description = "Marcin";
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
      ];
    };
  };
}
