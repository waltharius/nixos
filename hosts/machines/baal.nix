# hosts/machines/baal.nix - fields are described in hosts/README.md
# Registered with `nix run .#new-host` on 2026-10-01.
{
  class = "workstation";
  system = "x86_64-linux";
  description = "Dell Wyse 5470 - focus work laptop";
  tags = ["workstation" "laptop"];
  lan.ip = "192.168.50.82";
  users = {
    marcin.groups = ["cli" "emacs" "gnome" "media" "office" "web"];
  };

  # Age key derived from the SSH host key; its private part is stored
  # in secrets/hosts/baal/ssh_host_ed25519_key (admin keys only).
  sops = {
    ageKey = "age1a0983pr4znrryh9w0nkhtz2sp57fnwrhrnq64nv80wasjtaxyc0qp6sgfp";
    keySource = "ssh-host-key";
  };

  ssh.hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ1o3/Eqt0G2CUAjUIJlO5jZeNA8cKyrSEG8b46Bv2Ra";
}
