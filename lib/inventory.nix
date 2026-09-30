# lib/inventory.nix
#
# Loads the inventory, validates it and returns it:
#
#   hosts/fleet.nix            - fleet-wide settings (network, ...)
#   hosts/machines/<host>.nix  - one file per machine; the file name is the
#                                host name. Every *.nix file in the
#                                directory is loaded automatically.
#
# The result has the same shape as before the split:
#   { network = ...; machines.<host> = { ... }; }
#
# Any violation aborts evaluation with a list of all problems found, so
# mistakes surface at `nix flake check` / `nixos-rebuild` / `colmena eval`
# time instead of after a deployment.
#
# Rules:
#   - machine file names are valid host names ([a-z][a-z0-9-]*)
#   - every machine has a known class and a system
#   - "server" and "virtual" machines have a static LAN address (lan.ip)
#   - every lan.ip lies in the home LAN and outside the router's DHCP pool
#   - no two machines share a lan.ip
#   - every user has an account in users/<n>/account.nix
#   - every group of a user exists in modules/groups/default.nix
#   - "server" and "virtual" machines have the nixadm account
{
  lib,
  classes,
}: let
  knownGroups = builtins.attrNames (import ../modules/groups);
  fleet = import ../hosts/fleet.nix;

  # hosts/machines/<host>.nix -> machines.<host>
  machineFiles =
    lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".nix" file)
    (builtins.readDir ../hosts/machines);
  machines =
    lib.mapAttrs' (file: _:
      lib.nameValuePair (lib.removeSuffix ".nix" file) (import ../hosts/machines/${file}))
    machineFiles;

  raw = fleet // {inherit machines;};
  inherit (raw.network.lan) prefix dhcpPool;

  names = builtins.attrNames machines;

  classesRequiringIp = ["server" "virtual"];

  ipOf = m: m.lan.ip or null;

  # Last octet of an address in the home LAN, or null if outside the prefix.
  lastOctet = ip: let
    m = builtins.match "${lib.escapeRegex prefix}\\.([0-9]{1,3})" ip;
  in
    if m == null
    then null
    else lib.toInt (builtins.head m);

  errorsFor = name: let
    m = machines.${name};
    ip = ipOf m;
    octet =
      if ip == null
      then null
      else lastOctet ip;
  in
    lib.optional (builtins.match "[a-z][a-z0-9-]*" name == null)
    "${name}: hosts/machines/${name}.nix is not a valid host name ([a-z][a-z0-9-]*)"
    ++ lib.optional (!(m ? class)) "${name}: missing `class`"
    ++ lib.optional (m ? class && !(classes ? ${m.class}))
    "${name}: unknown class `${m.class}` (known: ${lib.concatStringsSep ", " (builtins.attrNames classes)})"
    ++ lib.optional (!(m ? system)) "${name}: missing `system`"
    ++ lib.optional (m ? class && builtins.elem m.class classesRequiringIp && ip == null)
    "${name}: class `${m.class}` requires a static `lan.ip`"
    ++ lib.optional (ip != null && octet == null)
    "${name}: lan.ip ${ip} is not in ${prefix}.0/24"
    ++ lib.optional (octet != null && (octet < 1 || octet > 254))
    "${name}: lan.ip ${ip} is not a usable host address"
    ++ lib.optional (octet != null && octet >= dhcpPool.first && octet <= dhcpPool.last)
    "${name}: lan.ip ${ip} is inside the router's DHCP pool (${prefix}.${toString dhcpPool.first}-${toString dhcpPool.last})"
    ++ lib.optional ((m.users or {}) == {}) "${name}: no `users`"
    ++ lib.optional (m ? class && builtins.elem m.class classesRequiringIp && !((m.users or {}) ? nixadm))
    "${name}: class `${m.class}` requires the nixadm account in `users`"
    ++ lib.concatLists (lib.mapAttrsToList (user: u:
      lib.optional (!builtins.pathExists ../users/${user}/account.nix)
      "${name}: user `${user}` has no users/${user}/account.nix"
      ++ map (g: "${name}: user `${user}` has unknown group `${g}` (known: ${lib.concatStringsSep ", " knownGroups})")
      (builtins.filter (g: !(builtins.elem g knownGroups)) (u.groups or [])))
    (m.users or {}));

  # Addresses used by more than one machine.
  ipOwners = lib.foldl' (acc: name: let
    ip = ipOf machines.${name};
  in
    if ip == null
    then acc
    else acc // {${ip} = (acc.${ip} or []) ++ [name];}) {}
  names;
  duplicateErrors =
    lib.mapAttrsToList (ip: owners: "lan.ip ${ip} is used by several machines: ${lib.concatStringsSep ", " owners}")
    (lib.filterAttrs (_: owners: builtins.length owners > 1) ipOwners);

  errors = lib.concatMap errorsFor names ++ duplicateErrors;
in
  if errors == []
  then raw
  else throw "the inventory (hosts/fleet.nix, hosts/machines/) is invalid:\n  - ${lib.concatStringsSep "\n  - " errors}"
