# lib/ssh.nix
#
# NixOS module generated from the inventory, imported by every host
# (lib/default.nix):
#
#   /etc/ssh/ssh_known_hosts  - host keys of the fleet (`ssh.hostKey` in
#                               hosts/machines/<host>.nix), of devices and
#                               aliases with `hostKey` (hosts/devices.nix),
#                               and the published keys of github.com and
#                               gitlab.com. No trust on first use for these.
#   fleet.ssh.fleetConfig     - ssh_config `Host` blocks for the NixOS
#                               machines (text)
#   fleet.ssh.devicesConfig   - ssh_config `Host` blocks for the devices
#
# The two texts are written to ~/.ssh/config.d/fleet and .../devices by
# users/marcin/home/ssh.nix (accounts with the nix-admin group only).
{
  lib,
  inventory,
}: {...}: let
  inherit (inventory) machines devices;

  identityFiles = {
    tabby = "~/.ssh/id_ed25519_tabby";
    gitlab = "~/.ssh/id_ed25519_gitlab";
    github = "~/.ssh/id_ed25519_github";
  };

  # Published SSH host keys, checked against the fingerprints on
  # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
  #   SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU
  # https://docs.gitlab.com/user/gitlab_com/#ssh-host-keys-fingerprints
  #   SHA256:eUXGGm1YGsMAS7vkcx6JOJdOGHPem5gQp4taiCfCLB8
  # When a provider rotates its key, follow docs/SSH.md ("Rotating pinned
  # host keys").
  external = {
    "github.com" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    "gitlab.com" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
  };

  # One SSH alias: { name, hostName, port, user, key, hostKey, extraOptions }.
  hostBlock = a:
    ''
      Host ${a.name}
    ''
    + lib.optionalString (a.hostName != null) "  HostName ${a.hostName}\n"
    + lib.optionalString (a.port != null) "  Port ${toString a.port}\n"
    + lib.optionalString (a.user != null) "  User ${a.user}\n"
    + lib.optionalString (a.key != null) "  IdentityFile ${identityFiles.${a.key}}\n"
    + lib.concatStrings (lib.mapAttrsToList (k: v: "  ${k} ${toString v}\n") a.extraOptions);

  # Name under which ssh looks the host up in known_hosts.
  knownName = a:
    if a.port == null || a.port == 22
    then a.hostName
    else "[${a.hostName}]:${toString a.port}";

  mkAlias = defaults: name: attrs:
    {
      inherit name;
      hostName = null;
      port = null;
      user = null;
      key = "tabby";
      hostKey = null;
      extraOptions = {};
    }
    // defaults
    // attrs;

  # --- machines -------------------------------------------------------------

  machineUser = m:
    if m.class == "workstation"
    then "marcin"
    else "nixadm";

  machineAliases = name: m: let
    ip = m.lan.ip or null;
  in
    [
      (mkAlias {} name {
        hostName = ip;
        user = machineUser m;
        hostKey = m.ssh.hostKey or null;
      })
    ]
    ++ lib.mapAttrsToList (mkAlias {hostName = ip;}) (m.ssh.aliases or {});

  # --- devices --------------------------------------------------------------

  deviceAliases = name: d:
    lib.mapAttrsToList (mkAlias {hostName = d.lan.ip or null;}) (d.ssh or {});

  sortedAliases = aliases: lib.sort (a: b: a.name < b.name) aliases;
  fleetAliases = sortedAliases (lib.concatLists (lib.mapAttrsToList machineAliases machines));
  deviceAliasList = sortedAliases (lib.concatLists (lib.mapAttrsToList deviceAliases devices));

  header = source: ''
    # GENERATED from ${source} - do not edit, changes are overwritten.
    # Permanent hosts: edit ${source} in the nixos repository.
    # Temporary or test hosts: ~/.ssh/config.d/local (never overwritten).
    # See ~/.ssh/config.d/README.md.

  '';

  # --- known_hosts ------------------------------------------------------------

  pinned = builtins.filter (a: a.hostKey != null) (fleetAliases ++ deviceAliasList);

  knownHostsFor = a: let
    # Machines and port-22 aliases are also known under their alias name.
    names =
      [(knownName a)]
      ++ lib.optional (a.port == null || a.port == 22) a.name;
  in {
    hostNames = lib.unique (builtins.filter (n: n != null) names);
    publicKey = a.hostKey;
  };
in {
  options.fleet.ssh = {
    fleetConfig = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "ssh_config Host blocks for the NixOS machines of the inventory.";
    };
    devicesConfig = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "ssh_config Host blocks for hosts/devices.nix.";
    };
  };

  config = {
    fleet.ssh.fleetConfig =
      header "hosts/machines/*.nix"
      + lib.concatMapStringsSep "\n" hostBlock fleetAliases;
    fleet.ssh.devicesConfig =
      header "hosts/devices.nix"
      + lib.concatMapStringsSep "\n" hostBlock deviceAliasList;

    programs.ssh.knownHosts =
      lib.listToAttrs (map (a: lib.nameValuePair "fleet-${a.name}" (knownHostsFor a)) pinned)
      // lib.mapAttrs (host: key: {
        hostNames = [host];
        publicKey = key;
      })
      external;
  };
}
