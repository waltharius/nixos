# hosts/devices/docker.nix - fields are described in hosts/README.md
{
  description = "Docker host (Proxmox guest)";
  lan.ip = "192.168.50.9";
  ssh.docker.user = "root";
  category = "proxmox-guest";
  monitoring = {
    ping = true;
    # node_exporter, installed with `nix run .#fleet` (monitoring apply).
    node = true;
    # Container metrics: cAdvisor installed with `nix run .#fleet`
    # (monitoring apply); runs portainer agent and atuin-server.
    cadvisor = true;
  };
}
