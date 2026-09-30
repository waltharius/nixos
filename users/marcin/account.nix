# users/marcin/account.nix
#
# System account of marcin: owner of the workstations, admin account.
# Imported on every host where hosts/machines/<host>.nix lists marcin.
# Unix groups required by marcin's program groups (e.g. `gamemode` for
# `gaming`) are added by lib/users.nix.
{...}: {
  users.users.marcin = {
    isNormalUser = true;
    description = "Marcin";
    extraGroups = ["networkmanager" "wheel" "input" "uinput" "plugdev"];
  };
}
