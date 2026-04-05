# modules/servers/ai/podman.nix
#
# Rootless-capable Podman OCI container runtime for the AI stack.
#
# Design decisions:
#   - Podman preferred over Docker: no daemon running as root, better
#     systemd integration, compatible with docker-compose images.
#   - docker.enable = false (explicit) to avoid socket conflicts.
#   - dockerCompat = true: creates /run/docker.sock symlink so any
#     image expecting the Docker socket works transparently.
#   - DNS for containers: 10.88.0.1 is the Podman default bridge gateway.
#     Containers use it to reach the host-side DNS resolver.
#   - The 10.88.0.0/16 range is Podman's default CNI bridge range.
#     It must NOT overlap with incusbr0 (10.0.0.x) or LAN (192.168.50.x).
{...}: {
  virtualisation.podman = {
    enable = true;
    # Provide /run/docker.sock compatibility shim — needed by Open-WebUI
    # and other images that probe for the Docker socket at startup.
    dockerCompat = true;
    # Clean up unused images/containers automatically.
    autoPrune.enable = true;
    defaultNetwork.settings = {
      # Default bridge subnet for podman containers.
      # Keep away from incusbr0 (10.0.0.x) and LAN (192.168.50.x).
      dns_enabled = true;
    };
  };

  # Disable Docker explicitly — prevents accidental enablement pulling in
  # the Docker daemon alongside Podman.
  virtualisation.docker.enable = false;
}
