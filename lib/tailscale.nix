# lib/tailscale.nix
#
# NixOS module generated from the inventory, imported by every host
# (lib/default.nix). A machine with a `tailscale` entry in
# hosts/machines/<host>.nix runs the Tailscale client; machines without one
# get only the option below. Servers and virtual machines have no entry:
# they are reached through the subnet router on pfSense
# (docs/REMOTE-ACCESS.md).
#
# `tailscale.join` decides how the machine joins and which client settings
# it gets:
#   owner  - marcin's own computers: logged in as marcin, MagicDNS and the
#            split DNS for home.lan (through systemd-resolved), the home LAN
#            route of the subnet router when `acceptRoutes`
#   tagged - computers marcin manages for someone else (stage 6): joined
#            with a one-off tagged auth key; no routes, no tailnet DNS
#   shared - a computer in its owner's own tailnet, shared with marcin; the
#            owner logs in; no routes, no tailnet DNS
#
# Client settings are re-applied on every boot with `tailscale set`
# (services.tailscale.extraSetFlags), so a manual change does not outlive a
# reboot. Logging in is a one-off step: `tailscale-join` on the host
# (interactive, prints a login URL), or at the first boot with the one-off
# key install-host leaves in /var/lib/tailscale-join/auth-key.
{
  lib,
  inventory,
}: {
  config,
  pkgs,
  host,
  ...
}: let
  ts = host.tailscale or null;
  enabled = ts != null;
  join =
    if enabled
    then ts.join
    else null;

  acceptRoutes = enabled && (ts.acceptRoutes or false);
  # Owners resolve tailnet names and home.lan through Tailscale's DNS.
  acceptDns = join == "owner";
  # Account allowed to run `tailscale up/down/set` without sudo.
  operator =
    if join == "owner"
    then ts.operator or "marcin"
    else null;
  tags =
    if enabled
    then ts.tags or []
    else [];

  # Tailscale's own control server unless hosts/fleet.nix names another
  # one (Headscale). Not for `shared`: that machine belongs to its owner's
  # tailnet.
  loginServer =
    if join == "shared"
    then null
    else inventory.tailscale.loginServer or null;

  lanCidr = "${inventory.network.lan.prefix}.0/24";

  boolFlag = name: value: "--${name}=${lib.boolToString value}";

  # Client preferences, re-applied on every boot by `tailscale set`.
  setFlags =
    [
      (boolFlag "accept-routes" acceptRoutes)
      (boolFlag "accept-dns" acceptDns)
    ]
    ++ lib.optional (operator != null) "--operator=${operator}";

  # `tailscale up` refuses to change preferences unless every non-default
  # one is given again, so tailscale-join passes the whole set; --reset
  # returns anything not listed here to its default.
  upFlags =
    ["--reset"]
    ++ setFlags
    ++ lib.optional (loginServer != null) "--login-server=${loginServer}"
    ++ lib.optional (tags != []) "--advertise-tags=${lib.concatStringsSep "," tags}";

  tailscaleJoin = pkgs.writeShellApplication {
    name = "tailscale-join";
    runtimeInputs = [config.services.tailscale.package];
    text = ''
      # Log this machine in to the tailnet with the settings from the
      # repository (lib/tailscale.nix). Extra arguments go to `tailscale up`,
      # e.g. --auth-key=file:/path/to/key.
      exec tailscale up ${lib.escapeShellArgs upFlags} "$@"
    '';
  };

  # Written by install-host (scripts/install-host.sh), removed after use.
  joinKey = "/var/lib/tailscale-join/auth-key";
in {
  options.fleet.tailscale.lanRoutingRule = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    description = ''
      NetworkManager routing rule for the home Wi-Fi profiles
      (modules/system/wifi.nix), or null. With the home LAN route accepted
      from the subnet router, Tailscale's policy routing would send LAN
      traffic through the tunnel even at home; this rule, active only while
      a home profile is up, looks the LAN up in the main table (254) first.
    '';
  };

  config = lib.mkMerge [
    {
      fleet.tailscale.lanRoutingRule =
        if acceptRoutes
        then "priority 2500 to ${lanCidr} table 254"
        else null;
    }

    (lib.mkIf enabled {
      services.tailscale = {
        enable = true;
        # Direct (peer-to-peer) connections instead of relays.
        openFirewall = true;
        # "client" loosens reverse path filtering for routed traffic.
        useRoutingFeatures =
          if acceptRoutes
          then "client"
          else "none";
        extraSetFlags = setFlags;
      };

      # Everything from the tailnet is allowed for now; the tailnet policy
      # (ACL, docs/REMOTE-ACCESS.md) decides who may connect. A per-port
      # firewall comes later (BACKLOG.md).
      networking.firewall.trustedInterfaces = ["tailscale0"];

      environment.systemPackages =
        [tailscaleJoin]
        ++ lib.optional (join == "owner") pkgs.tailscale-systray;

      # Without a DNS manager Tailscale rewrites /etc/resolv.conf and fights
      # NetworkManager over it; with systemd-resolved it adds its DNS per
      # interface (https://tailscale.com/docs/reference/linux-dns).
      services.resolved.enable = lib.mkIf acceptDns true;
      networking.networkmanager.dns = lib.mkIf acceptDns "systemd-resolved";

      # First boot after install-host: join with the one-off key, then
      # delete it. Skipped when the key file does not exist.
      systemd.services.tailscale-join-once = lib.mkIf (join != "shared") {
        description = "Join the tailnet with the one-off key left by install-host";
        wants = ["network-online.target" "tailscaled.service"];
        after = ["network-online.target" "tailscaled.service" "tailscaled-set.service"];
        wantedBy = ["multi-user.target"];
        unitConfig = {
          ConditionPathExists = joinKey;
          # Wi-Fi may come up late on the first boot: retry for a while.
          StartLimitIntervalSec = 900;
          StartLimitBurst = 10;
        };
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = 30;
        };
        script = ''
          ${lib.getExe tailscaleJoin} --auth-key=file:${joinKey} --timeout=60s
          rm -f ${joinKey}
        '';
      };
    })
  ];
}
