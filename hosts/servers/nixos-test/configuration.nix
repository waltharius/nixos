{
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    ../../../modules/system/certificates.nix
    ../../../modules/servers/users.nix  # Add nixadm user
  ];

  system.stateVersion = "25.11";

  # Nix settings for remote deployment
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    
    # Trust nixadm and wheel group for Colmena deployments
    # This allows copying store paths without signature verification
    trusted-users = [ "nixadm" "root" "@wheel" ];
    
    # Disable sandbox in LXC containers (kernel namespace limitations)
    sandbox = false;
  };

  networking = {
    hostName = "nixos-test";
    domain = "home.lan";  # DNS integration with FreeIPA
    search = [ "home.lan" ];
    nameservers = [ "192.168.50.1" ];  # FreeIPA DNS
    useDHCP = lib.mkDefault true;
    firewall.enable = true;
    firewall.allowedTCPPorts = [22];
  };

  # Use systemd-resolved for DNS (with FreeIPA)
  services.resolved = {
    enable = true;
    dnssec = "false";
    domains = ["home.lan"];
    fallbackDns = ["9.9.9.9"];  # Quad9 fallback
    extraConfig = ''
      [Resolve]
      DNS=192.168.50.1
      Domains=home.lan
      DNSoverTLS=no
    '';
  };

  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";

  # Common server packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
    bind
    eza       # Modern ls replacement
    zoxide    # Smart cd
    starship  # Customizable prompt
  ];

  # SSH configuration (managed by users.nix module)
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };
}
