{...}: {
  security.sudo = {
    enable = true;
    extraConfig = ''
      Defaults tty_tickets
      Defaults timestamp_timeout=60

      # Optional: Configure specific timeout for nixos-rebuild-like commands
      # Defaults!/run/current-system/sw/bin/nixos-rebuild timestamp_timeout=60
    '';
  };
}
