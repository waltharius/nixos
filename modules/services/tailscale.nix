# ../modules/services/tailscale.nix
# Tailscale client for laptop — manual on-demand activation.
# The daemon runs always (lightweight) but does NOT auto-connect.
# Connect manually: sudo tailscale up --accept-routes
# Disconnect:       sudo tailscale down
#
# Why keep the daemon running but not connected:
# - tailscale up/down is instant (~1 second)
# - stopping/starting the systemd service is slower and noisier
# - the daemon uses ~0 CPU and ~20MB RAM when disconnected
{config, ...}: {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  networking.firewall = {
    allowedUDPPorts = [config.services.tailscale.port];
    trustedInterfaces = ["tailscale0"];
  };
}
