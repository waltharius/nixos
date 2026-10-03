# hosts/devices/walthpi16.nix - fields are described in hosts/README.md
{
  description = "Raspberry Pi - also runs GitLab (SSH on port 2424)";
  lan.ip = "192.168.50.46";
  ssh = {
    walthpi16.user = "walthpi";
    gitlab-host = {
      # The name the repositories use (ssh://git@gitlab.home.lan:2424/...),
      # so the pinned key below is found under it: ssh looks up
      # [gitlab.home.lan]:2424 in known_hosts.
      hostName = "gitlab.home.lan";
      user = "git";
      port = 2424;
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7BmOynY5MjyVY0Thyr/Uxy8X1c9ppRW6brptgDtdJR";
      key = "gitlab";
      extraOptions.PreferredAuthentications = "publickey";
    };
  };
  monitoring = {
    ping = true;
    # Container metrics: cAdvisor installed with `nix run .#fleet`
    # (monitoring apply); runs gitlab-ce, vikunja and portainer.
    cadvisor = true;
  };
}
