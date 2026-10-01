# users/marcin/account.nix
#
# System account of marcin: owner of the workstations, admin account.
# Imported on every host where hosts/machines/<host>.nix lists marcin.
# Unix groups required by marcin's program groups (e.g. `gamemode` for
# `gaming`) are added by lib/users.nix.
{...}: {
  # SSH keys (system sops-nix), chosen by marcin's groups on the host.
  imports = [./secrets.nix];

  users.users.marcin = {
    isNormalUser = true;
    description = "Marcin";
    extraGroups = ["networkmanager" "wheel" "input" "uinput" "plugdev"];

    # SSH logins from the admin workstations: the LAN admin key (tabby),
    # whose private part only hosts where marcin has nix-admin receive
    # (users/marcin/secrets.nix). The fleet ssh config uses it for every
    # machine (lib/ssh.nix). Keys in ~/.ssh/authorized_keys keep working.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
    ];
  };
}
