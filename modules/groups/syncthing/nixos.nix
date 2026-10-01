# modules/groups/syncthing/nixos.nix
#
# Group `syncthing`, system part: Syncthing running as the account that has
# the group on this host (hosts/machines/<host>.nix), with its data in that
# account's home. Devices and folders are still configured in the web UI
# (http://127.0.0.1:8384); see BACKLOG for the declarative plan.
{
  host,
  lib,
  ...
}: let
  users = builtins.filter (u: builtins.elem "syncthing" (host.users.${u}.groups or [])) (builtins.attrNames host.users);
  user = builtins.head users;
in {
  assertions = [
    {
      assertion = builtins.length users == 1;
      message = "group `syncthing`: exactly one account per host may have it (${host.name}: ${lib.concatStringsSep ", " users})";
    }
  ];

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    inherit user;
    dataDir = "/home/${user}";
    configDir = "/home/${user}/.config/syncthing";
  };
}
