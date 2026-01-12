# hosts/containers/base-template/configuration.nix
# This is configuration file for building Proxmox LXC container
# on a computer with Nix insalles (doesn't require to be a NixOS)
{
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  # Import the Proxmox LXC profile
  imports = [
    # This will import build-in module directly from nixpkgs in nix store.
    # proxmox-lxc.nix can be found here:
    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/proxmox-lxc.nix
    "${modulesPath}/virtualisation/proxmox-lxc.nix"

    # Import shared server configurations below:
    ../../../modules/system/server-vim.nix
    ../../../modules/system/server-tmux.nix
  ];

  # System version - IMPORTANT for tracking
  system.stateVersion = "25.11";

  # Enable flakes for remote management
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    sandbox = false;
    trusted-users = ["root" "nixadm" "@wheel"];
    keep-outputs = false;
    keep-derivations = false;
  };

  # Network configuration
  # Proxmox will handle the actual network setup, but we need basic settings
  networking = {
    useDHCP = lib.mkDefault true;
    firewall.enable = true;
    firewall.allowedTCPPorts = [22]; # SSH only
  };

  # Time zone - adjust to your location
  time.timeZone = "Europe/Warsaw";

  # Locale settings - adjust to your location
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    # Leave for Poland, change if other country needed
    LC_TIME = "pl_PL.UTF-8";
    LC_MEASUREMENT = "pl_PL.UTF-8";
  };

  # Essential packages for remote management
  environment.systemPackages = with pkgs; [
    git
    htop
    btop
    curl
    wget
    tree
    ripgrep
    fzf
    yazi
    fd
  ];

  # SSH configuration - CRITICAL for remote management
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password"; # Only allow key-based auth
      PasswordAuthentication = false; # Disable password auth
    };
  };

  # Root user setup with your SSH key
  users.users.root = {
    openssh.authorizedKeys.keys = [
      # REPLACE with your actual SSH public key from your main machines
      # You can get it with: cat ~/.ssh/id_ed25519.pub (or id_rsa.pub)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
    ];
  };

  # Optional: Create a non-root user for better security
  users.users.nixadm = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable sudo
    openssh.authorizedKeys.keys = [
      # Same SSH key as root
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
    ];
  };

  # Allow sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;

  systemd.tmpfiles.rules = [
    "d /var/lib/sops-nix 0755 root root -"
  ];

  # DO NOT enable auto-upgrade in the template
  # Updates will be managed via Colmena deployment
}
