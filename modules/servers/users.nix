# SSH and sudo policy of servers and virtual machines.
# The nixadm account itself is defined in users/nixadm/account.nix.
{lib, ...}: {
  # Disable root SSH login for security
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "no";
  };

  # Passwordless sudo for wheel group (nixadm)
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}
