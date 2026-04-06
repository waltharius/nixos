# modules/services/podman.nix
# Podman service for winboat application installed on laptops.
# Must be inported in confguration.nix for a laptop.
{pkgs, ...}: {
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # symlinks /run/podman/podman.sock as docker.sock
    defaultNetwork.settings.dns_enabled = true;
  };

  # Required for rootless containers with multiple UIDs
  security.unprivilegedUsernsClone = true;

  # Needed by winboat's podman-compose
  environment.systemPackages = with pkgs; [
    podman-compose
  ];
}
