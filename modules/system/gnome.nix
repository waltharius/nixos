# GNOME Desktop Environment configuration
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable X11 windowing system
  services.xserver = {
    enable = true;

    # Keyboard repeat rate
    autoRepeatDelay = 200;
    autoRepeatInterval = 35;
  };

  # Enable GDM display manager
  services.displayManager.gdm.enable = true;

  # Enable GNOME Desktop
  services.desktopManager.gnome = {
    enable = true;

    # Enable fractional scaling
    extraGSettingsOverridePackages = [pkgs.mutter];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };

  # Enable GNOME Keyring with SSH agent support
  services.gnome.gnome-keyring.enable = true;

  # Enable PAM integration to auto-unlock keyring with login password
  security.pam.services = {
    gdm.enableGnomeKeyring = true;
    login.enableGnomeKeyring = true;
  };

  programs.dconf.enable = true;
  services.gnome.gcr-ssh-agent.enable = true;

  # Ensure system-wide SSH agent doesn't conflict
  programs.ssh.startAgent = false;

  # Remove unwanted GNOME packages
  environment.gnome.excludePackages = with pkgs; [
    geary
    epiphany
    gnome-tour
    gnome-maps
    cheese
  ];

  # Enable Flatpak for additional applications
  services.flatpak.enable = true;

  # XDG portal for Flatpak integration
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };

  # Enable CUPS for printing
  services.printing = {
    enable = true;
    drivers = [pkgs.cups-filters];
    # Disable CUPS's own auto-queue creation from dnssd backend
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

  # Override nsswitch to allow DNS fallback after mdns4_minimal
  system.nssDatabases.hosts = lib.mkForce [
    "mymachines"
    "mdns4_minimal"
    "files"
    "myhostname"
    "dns"
    "mdns4"
  ];

  # Persist the Canon printer across rebuilds
  systemd.services.cups-add-canon = {
    description = "Add Canon TS8300 printer to CUPS";
    after = ["cups.service" "network-online.target"];
    wants = ["cups.service" "network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Retry up to 5 times if it fails, with 5s delay between attempts
      Restart = "on-failure";
      RestartSec = "5s";
    };
    script = ''
      # Wait until CUPS socket is actually accepting connections
      for i in $(seq 1 10); do
        if ${pkgs.cups}/bin/lpstat -r 2>/dev/null | grep -q "running"; then
          break
        fi
        echo "Waiting for CUPS... attempt $i"
        sleep 3
      done

      # Wait until the printer is reachable on the network
      for i in $(seq 1 10); do
        if ${pkgs.iputils}/bin/ping -c1 -W2 drukarka.home.lan >/dev/null 2>&1; then
          break
        fi
        echo "Waiting for printer on network... attempt $i"
        sleep 3
      done

      # Only add if not already present
      if ! ${pkgs.cups}/bin/lpstat -v 2>/dev/null | grep -q "CanonTS8300"; then
        ${pkgs.cups}/bin/lpadmin \
          -p CanonTS8300 \
          -E \
          -v "ipp://192.168.50.101/ipp/print" \
          -m everywhere \
          -D "Canon Pixma TS8300"
        ${pkgs.cups}/bin/lpoptions -d CanonTS8300
      fi
    '';
  };

  # Enable PipeWire for audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  systemd.user.services.gsd-power = {
    enable = false;
  };

  systemd.user.services."org.gnome.SettingsDaemon.Power" = {
    enable = false;
  };
}
