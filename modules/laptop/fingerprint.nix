# ./modules/laptop/fingerprint.nix
# Fingerprint authentication module for laptops with fingerprint readers
# Configures PAM to use fprintd for GNOME login, sudo, polkit, and keyring unlock
{pkgs, ...}: {
  # Enable fprintd service
  services.fprintd.enable = true;

  # Configure PAM to use fingerprint authentication
  # Using 'sufficient' means fingerprint OR password works (safer fallback)
  security.pam.services = {
    # GNOME Display Manager (login screen)
    gdm.fprintAuth = true;
    gdm-fingerprint.fprintAuth = true;

    # Sudo authentication
    sudo.fprintAuth = true;

    # Polkit authentication (for system settings, package installation, etc.)
    polkit-1.fprintAuth = true;

    # GNOME Keyring unlock (for stored passwords, SSH keys, etc.)
    # This is crucial for automatic keyring unlock after fingerprint login
    login.fprintAuth = true;

    # Screen lock authentication
    gnome-keyring.fprintAuth = true;
  };

  # Add fprintd package to system for enrolling fingerprints
  environment.systemPackages = with pkgs; [
    fprintd
  ];
}
