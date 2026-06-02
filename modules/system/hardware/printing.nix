# modules/system/hardware/printing.nix
#
# CUPS printing stack + Avahi mDNS + automatic Canon TS8300 registration.
#
# Extracted from modules/system/desktop/gnome.nix so that printing works
# independently of the desktop environment. The printer is accessed over
# the network via IPP Everywhere (driverless), so no vendor PPD is needed.
#
# Avahi provides mDNS/DNS-SD (compatible with Apple Bonjour), which is used
# to resolve local hostnames such as drukarka.home.lan. It modifies
# /etc/nsswitch.conf through the NixOS nss module system.
#
# The nssDatabases.hosts override with lib.mkForce is required because the
# default Avahi + NixOS configuration inserts mdns4_minimal as the first
# resolver and treats *.lan as a local-only zone, silently suppressing DNS
# fallback. The forced ordering restores the expected behaviour: mDNS is
# tried first for .local names, then standard DNS handles everything else.
# lib.mkForce is used (rather than lib.mkDefault) to prevent other modules
# from silently reverting this ordering.
#
# cups-browsed is disabled because it auto-discovers and registers remote
# printers, which creates ghost print queues on networks with many shared
# printers. The Canon printer is managed declaratively through the oneshot
# systemd service below.
#
# The cups-add-canon service uses a oneshot + RemainAfterExit pattern so
# that systemd marks it as "active" after the script completes and does not
# re-run it on dependency restarts. hardware.printers is intentionally not
# used here because it relies on PPD files and does not support IPP
# Everywhere / driverless printing correctly.
{ lib, pkgs, ... }: {

  services.printing = {
    enable = true;
    drivers = [ pkgs.cups-filters ];
    # Disable automatic remote queue discovery to avoid ghost printers.
    extraConf = ''
      BrowseRemoteProtocols none
      BrowseLocalProtocols none
      BrowseSubscriptions No
    '';
  };

  systemd.services.cups-browsed.enable = false;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Restore DNS fallback after mdns4_minimal for non-.local names.
  # See module header for full explanation.
  system.nssDatabases.hosts = lib.mkForce [
    "mymachines"
    "mdns4_minimal"
    "files"
    "myhostname"
    "dns"
    "mdns4"
  ];

  # Register the Canon TS8300 printer in CUPS on every system activation.
  # The script waits for both the CUPS daemon and the printer's IP to be
  # reachable before attempting registration, which makes the service
  # resilient to boot ordering and slow network initialisation.
  # The printer IP (192.168.50.101) is a static DHCP lease in pfSense, so
  # it is stable across printer reboots.
  systemd.services.cups-add-canon = {
    description = "Register Canon TS8300 printer in CUPS";
    after = [ "cups.service" "network-online.target" ];
    wants = [ "cups.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "5s";
    };
    script = ''
      for i in $(seq 1 10); do
        if ${pkgs.cups}/bin/lpstat -r 2>/dev/null | grep -q "running"; then
          break
        fi
        echo "cups-add-canon: waiting for CUPS... attempt $i"
        sleep 3
      done

      # Use IP address directly; DNS name resolution is not guaranteed at
      # this point in the boot sequence even when pfSense resolves the name
      # correctly at runtime.
      for i in $(seq 1 10); do
        if ${pkgs.iputils}/bin/ping -c1 -W2 192.168.50.101 >/dev/null 2>&1; then
          break
        fi
        echo "cups-add-canon: waiting for printer at 192.168.50.101... attempt $i"
        sleep 3
      done

      if ! ${pkgs.cups}/bin/lpstat -v 2>/dev/null | grep -q "CanonTS8300"; then
        ${pkgs.cups}/bin/lpadmin \
          -p CanonTS8300 \
          -E \
          -v "ipp://192.168.50.101/ipp/print" \
          -m everywhere \
          -D "Canon Pixma TS8300"
        ${pkgs.cups}/bin/lpoptions -d CanonTS8300
        echo "cups-add-canon: printer registered successfully"
      else
        echo "cups-add-canon: printer already registered, skipping"
      fi
    '';
  };
}
