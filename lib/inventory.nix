# lib/inventory.nix
#
# Loads hosts/inventory.nix, validates it and returns it unchanged.
# Any violation aborts evaluation with a list of all problems found, so
# mistakes surface at `nix flake check` / `nixos-rebuild` / `colmena eval`
# time instead of after a deployment.
#
# Rules:
#   - every machine has a known class and a system
#   - "server" and "virtual" machines have a static LAN address (lan.ip)
#   - every lan.ip lies in the home LAN and outside the router's DHCP pool
#   - no two machines share a lan.ip
{
  lib,
  classes,
}: let
  raw = import ../hosts/inventory.nix;
  inherit (raw.network.lan) prefix dhcpPool;

  machines = raw.machines;
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
    lib.optional (!(m ? class)) "${name}: missing `class`"
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
    "${name}: lan.ip ${ip} is inside the router's DHCP pool (${prefix}.${toString dhcpPool.first}-${toString dhcpPool.last})";

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
  else throw "hosts/inventory.nix is invalid:\n  - ${lib.concatStringsSep "\n  - " errors}"
