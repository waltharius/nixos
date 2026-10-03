# lib/inventory.nix
#
# Loads the inventory, validates it and returns it:
#
#   hosts/fleet.nix            - fleet-wide settings (network, ...)
#   hosts/machines/<host>.nix  - one file per machine; the file name is the
#                                host name. Every *.nix file in the
#                                directory is loaded automatically.
#   hosts/devices/<name>.nix   - one file per device that is not a NixOS
#                                machine (address plan, SSH aliases, host
#                                keys, monitoring); loaded like machines
#   hosts/websites.nix         - web pages probed by the monitoring
#
# The result:
#   { network; sops; tailscale; monitoring; machines.<host>;
#     devices.<device>; websites.<site>; }
#
# Any violation aborts evaluation with a list of all problems found, so
# mistakes surface at `nix flake check` / `nixos-rebuild` / `colmena eval`
# time instead of after a deployment.
#
# Rules:
#   - machine file names are valid host names ([a-z][a-z0-9-]*)
#   - every machine has a known class and a system
#   - "server" and "virtual" machines have a static LAN address (lan.ip);
#     "server" machines also name the interface it is set on (lan.interface)
#   - every lan.ip lies in the home LAN and outside the router's DHCP pool
#   - no two machines share a lan.ip
#   - every user has an account in users/<n>/account.nix
#   - every group of a user exists in modules/groups/default.nix
#   - "server" and "virtual" machines have the nixadm account
#   - every machine has an age public key (sops.ageKey) and a known
#     sops.keySource; files in sops.extraSecrets exist
#   - every admin key in hosts/fleet.nix is an age public key
#   - devices follow the same address rules; machines and devices never
#     share an address
#   - SSH alias names (machine names, `ssh.aliases`, device `ssh`) are
#     unique
#   - `tailscale` (lib/tailscale.nix): known fields only; `join` is owner,
#     tagged or shared; owner and shared only on workstations; acceptRoutes
#     and operator only with owner, the operator has an account on the
#     machine; tagged needs tags (tag:<name>), the others have none
#   - tailscale.loginServer in hosts/fleet.nix is null or an https:// URL
#   - `monitoring` in hosts/fleet.nix names an existing machine of class
#     server as `server`, and mail addresses that contain an @
#   - device `monitoring` has known fields only; `ping`, `pve` and
#     `cadvisor` need `lan.ip`, `cadvisor` also an SSH alias named like the
#     device
#   - websites have a valid name and an http:// or https:// `url`
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
  machines = lib.mapAttrs' (file: _:
    lib.nameValuePair (lib.removeSuffix ".nix" file) (import ../hosts/machines/${file}))
  machineFiles;

  # hosts/<dir>/<name>.nix -> <name> = import ...; every *.nix file.
  loadDir = dir:
    lib.mapAttrs' (file: _: lib.nameValuePair (lib.removeSuffix ".nix" file) (import (dir + "/${file}")))
    (lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".nix" file)
      (builtins.readDir dir));

  devices = loadDir ../hosts/devices;
  deviceNames = builtins.attrNames devices;

  websites = import ../hosts/websites.nix;

  raw = fleet // {inherit machines devices websites;};
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

  # age X25519 public key: "age1" + 58 bech32 characters.
  isAgeKey = key: builtins.isString key && builtins.match "age1[02-9ac-hj-np-z]{58}" key != null;
  keySources = ["key-file" "ssh-host-key"];

  # Tailscale client of a machine (lib/tailscale.nix).
  tailscaleJoins = ["owner" "tagged" "shared"];
  tailscaleFields = ["join" "acceptRoutes" "tags" "operator"];
  isTag = t: builtins.isString t && builtins.match "tag:[a-z0-9][a-z0-9-]*" t != null;

  tailscaleErrors = name: m: let
    ts = m.tailscale;
    join = ts.join or null;
    operator = ts.operator or "marcin";
    label = "${name}: tailscale";
  in
    if !builtins.isAttrs ts
    then ["${label} must be an attribute set, e.g. { join = \"owner\"; }"]
    else
      map (f: "${label}: unknown field `${f}` (known: ${lib.concatStringsSep ", " tailscaleFields})")
      (builtins.filter (f: !(builtins.elem f tailscaleFields)) (builtins.attrNames ts))
      ++ lib.optional (!(builtins.elem join tailscaleJoins))
      "${label}.join must be one of ${lib.concatStringsSep ", " tailscaleJoins}"
      ++ lib.optional (builtins.elem join ["owner" "shared"] && (m.class or null) != "workstation")
      "${label}.join = \"${join}\" is for workstations; servers are reached through the subnet router (docs/REMOTE-ACCESS.md)"
      ++ lib.optional (ts ? acceptRoutes && !builtins.isBool ts.acceptRoutes)
      "${label}.acceptRoutes must be true or false"
      ++ lib.optional ((ts.acceptRoutes or false) == true && join != "owner")
      "${label}.acceptRoutes is only for join = \"owner\""
      ++ lib.optional (join == "tagged" && (ts.tags or []) == [])
      "${label}: join = \"tagged\" needs `tags`, e.g. [\"tag:managed\"]"
      ++ lib.optional (join != "tagged" && ts ? tags)
      "${label}.tags are only for join = \"tagged\""
      ++ map (t: "${label}.tags: ${builtins.toJSON t} is not a tag (tag:<name>; lowercase letters, digits, -)")
      (builtins.filter (t: !isTag t) (ts.tags or []))
      ++ lib.optional (ts ? operator && join != "owner")
      "${label}.operator is only for join = \"owner\""
      ++ lib.optional (join == "owner" && !((m.users or {}) ? ${operator}))
      "${label}: operator `${operator}` has no account on ${name} (users)";

  loginServer = raw.tailscale.loginServer or null;
  fleetTailscaleErrors =
    lib.optional (loginServer != null && !(builtins.isString loginServer && lib.hasPrefix "https://" loginServer))
    "hosts/fleet.nix: tailscale.loginServer must be null (Tailscale) or an https:// URL (Headscale)";

  # --- monitoring (lib/monitoring.nix) -------------------------------------

  monitoring = raw.monitoring or {};
  monitoringServer = monitoring.server or null;
  isMailAddress = a: builtins.isString a && builtins.match "[^@ ]+@[^@ ]+" a != null;

  fleetMonitoringErrors =
    lib.optional (monitoringServer == null)
    "hosts/fleet.nix: `monitoring.server` must name the machine that runs Prometheus"
    ++ lib.optional (monitoringServer != null && !(machines ? ${monitoringServer}))
    "hosts/fleet.nix: monitoring.server `${toString monitoringServer}` is not a machine in hosts/machines/"
    ++ lib.optional (monitoringServer != null && machines ? ${monitoringServer} && (machines.${monitoringServer}.class or null) != "server")
    "hosts/fleet.nix: monitoring.server `${monitoringServer}` must be of class server"
    ++ lib.optional (!isMailAddress (monitoring.mail.to or null))
    "hosts/fleet.nix: monitoring.mail.to must be an e-mail address"
    ++ lib.optional (!isMailAddress (monitoring.mail.from or null))
    "hosts/fleet.nix: monitoring.mail.from must be an e-mail address";

  # Fields a device may set under `monitoring`.
  deviceMonitoringFields = ["ping" "pve" "cadvisor"];

  deviceMonitoringErrors = name: d: let
    mon = d.monitoring;
    label = "device ${name}: monitoring";
  in
    if !builtins.isAttrs mon
    then ["${label} must be an attribute set, e.g. { ping = true; }"]
    else
      map (f: "${label}: unknown field `${f}` (known: ${lib.concatStringsSep ", " deviceMonitoringFields})")
      (builtins.filter (f: !(builtins.elem f deviceMonitoringFields)) (builtins.attrNames mon))
      ++ lib.optional (mon ? ping && !builtins.isBool mon.ping)
      "${label}.ping must be true or false"
      ++ lib.optional ((mon.ping or false) && ipOf d == null)
      "${label}.ping needs the device's `lan.ip`"
      ++ lib.optional (mon ? pve && !builtins.isBool mon.pve)
      "${label}.pve must be true or false"
      ++ lib.optional ((mon.pve or false) && ipOf d == null)
      "${label}.pve needs the device's `lan.ip`"
      ++ lib.optional (mon ? cadvisor && !builtins.isBool mon.cadvisor)
      "${label}.cadvisor must be true or false"
      ++ lib.optional ((mon.cadvisor or false) && ipOf d == null)
      "${label}.cadvisor needs the device's `lan.ip`"
      # `nix run .#fleet` (monitoring apply) logs in through the SSH alias
      # named like the device.
      ++ lib.optional ((mon.cadvisor or false) && !((d.ssh or {}) ? ${name}))
      "${label}.cadvisor needs an SSH alias named like the device (ssh.${name}), used by `nix run .#fleet`";

  websiteFields = ["url" "description"];

  websiteErrorsFor = name: let
    w = websites.${name};
    label = "website ${name} (hosts/websites.nix)";
  in
    lib.optional (builtins.match "[a-z][a-z0-9-]*" name == null)
    "${label}: not a valid name ([a-z][a-z0-9-]*)"
    ++ map (f: "${label}: unknown field `${f}` (known: ${lib.concatStringsSep ", " websiteFields})")
    (builtins.filter (f: !(builtins.elem f websiteFields)) (builtins.attrNames w))
    ++ lib.optional (!(builtins.isString (w.url or null) && builtins.match "https?://.+" w.url != null))
    "${label}: `url` must start with http:// or https://";

  adminErrors =
    lib.optional ((raw.sops.admins or {}) == {}) "hosts/fleet.nix: no admin key in `sops.admins`"
    ++ lib.concatLists (lib.mapAttrsToList (n: key:
      lib.optional (!isAgeKey key) "hosts/fleet.nix: sops.admins.${n} is not an age public key")
    (raw.sops.admins or {}));

  # Address rules shared by machines and devices.
  addressErrors = label: ip: let
    octet = lastOctet ip;
  in
    lib.optional (octet == null)
    "${label}: lan.ip ${ip} is not in ${prefix}.0/24"
    ++ lib.optional (octet != null && (octet < 1 || octet > 254))
    "${label}: lan.ip ${ip} is not a usable host address"
    ++ lib.optional (octet != null && octet >= dhcpPool.first && octet <= dhcpPool.last)
    "${label}: lan.ip ${ip} is inside the router's DHCP pool (${prefix}.${toString dhcpPool.first}-${toString dhcpPool.last})";

  errorsFor = name: let
    m = machines.${name};
    ip = ipOf m;
  in
    lib.optional (builtins.match "[a-z][a-z0-9-]*" name == null)
    "${name}: hosts/machines/${name}.nix is not a valid host name ([a-z][a-z0-9-]*)"
    ++ lib.optional (!(m ? class)) "${name}: missing `class`"
    ++ lib.optional (m ? class && !(classes ? ${m.class}))
    "${name}: unknown class `${m.class}` (known: ${lib.concatStringsSep ", " (builtins.attrNames classes)})"
    ++ lib.optional (!(m ? system)) "${name}: missing `system`"
    ++ lib.optional (m ? class && builtins.elem m.class classesRequiringIp && ip == null)
    "${name}: class `${m.class}` requires a static `lan.ip`"
    ++ lib.optional ((m.class or null) == "server" && !(m.lan ? interface))
    "${name}: class `server` requires `lan.interface` (the NIC the static address is set on)"
    ++ lib.optionals (ip != null) (addressErrors name ip)
    ++ lib.optional ((m.users or {}) == {}) "${name}: no `users`"
    ++ lib.optional (m ? class && builtins.elem m.class classesRequiringIp && !((m.users or {}) ? nixadm))
    "${name}: class `${m.class}` requires the nixadm account in `users`"
    ++ lib.optional (!isAgeKey (m.sops.ageKey or null))
    "${name}: `sops.ageKey` is missing or not an age public key (age1...)"
    ++ lib.optional (!(builtins.elem (m.sops.keySource or null) keySources))
    "${name}: `sops.keySource` must be one of ${lib.concatStringsSep ", " keySources}"
    ++ map (f: "${name}: sops.extraSecrets: ${f} does not exist")
    (builtins.filter (f: !builtins.pathExists (../. + "/${f}")) (m.sops.extraSecrets or []))
    ++ lib.concatLists (lib.mapAttrsToList (user: u:
      lib.optional (!builtins.pathExists ../users/${user}/account.nix)
      "${name}: user `${user}` has no users/${user}/account.nix"
      ++ map (g: "${name}: user `${user}` has unknown group `${g}` (known: ${lib.concatStringsSep ", " knownGroups})")
      (builtins.filter (g: !(builtins.elem g knownGroups)) (u.groups or [])))
    (m.users or {}))
    ++ lib.optionals (m ? tailscale) (tailscaleErrors name m);

  deviceErrorsFor = name: let
    d = devices.${name};
    ip = ipOf d;
  in
    lib.optional (builtins.match "[a-z][a-z0-9-]*" name == null)
    "device ${name}: not a valid name ([a-z][a-z0-9-]*)"
    ++ lib.optional (machines ? ${name}) "device ${name}: a machine has the same name"
    ++ lib.optionals (ip != null) (addressErrors "device ${name}" ip)
    ++ lib.optional (ip == null && lib.any (a: !(a ? hostName)) (lib.attrValues (d.ssh or {})))
    "device ${name}: an SSH alias without `hostName` needs the device's `lan.ip`"
    ++ lib.optionals (d ? monitoring) (deviceMonitoringErrors name d);

  # Addresses used by more than one machine or device.
  addressOwners =
    map (n: {
      name = n;
      ip = ipOf machines.${n};
    })
    names
    ++ map (n: {
      name = "device ${n}";
      ip = ipOf devices.${n};
    })
    deviceNames;
  ipOwners = lib.foldl' (acc: o:
    if o.ip == null
    then acc
    else acc // {${o.ip} = (acc.${o.ip} or []) ++ [o.name];}) {}
  addressOwners;
  duplicateErrors =
    lib.mapAttrsToList (ip: owners: "lan.ip ${ip} is used several times: ${lib.concatStringsSep ", " owners}")
    (lib.filterAttrs (_: owners: builtins.length owners > 1) ipOwners);

  # SSH aliases: machine names, machine `ssh.aliases`, device `ssh` entries.
  aliases =
    names
    ++ lib.concatMap (n: builtins.attrNames (machines.${n}.ssh.aliases or {})) names
    ++ lib.concatMap (n: builtins.attrNames (devices.${n}.ssh or {})) deviceNames;
  aliasErrors =
    map (a: "SSH alias ${a} is defined several times")
    (lib.unique (builtins.filter (a: lib.count (x: x == a) aliases > 1) aliases));

  errors =
    adminErrors
    ++ fleetTailscaleErrors
    ++ fleetMonitoringErrors
    ++ lib.concatMap websiteErrorsFor (builtins.attrNames websites)
    ++ lib.concatMap errorsFor names
    ++ lib.concatMap deviceErrorsFor deviceNames
    ++ duplicateErrors
    ++ aliasErrors;
in
  if errors == []
  then raw
  else throw "the inventory (hosts/fleet.nix, hosts/machines/, hosts/devices/, hosts/websites.nix) is invalid:\n  - ${lib.concatStringsSep "\n  - " errors}"
