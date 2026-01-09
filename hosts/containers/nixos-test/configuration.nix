{
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    ../../../modules/system/certificates.nix
  ];

  system.stateVersion = "25.11";

  nix.settings.experimental-features = ["nix-command" "flakes"];

  networking = {
    hostName = "nixos-test";
    useDHCP = lib.mkDefault true;
    firewall.enable = true;
    firewall.allowedTCPPorts = [22];
  };

  services.resolved = {
    enable = true;
    dnssec = "false";
    domains = ["home.lan"];
    fallbackDns = ["9.9.9.11"];
    extraConfig = ''
      [Resolve]
      DNS=192.168.50.1
      Domains=home.lan
      DNSoverTLS=no
    '';
  };

  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
    bind
    atuin
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # YOUR SSH PUBLIC KEY HERE
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
  ];
}
