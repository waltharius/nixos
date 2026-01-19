# ./modules/laptop/fingerprint.nix
# Fingerprint authentication module for laptops with fingerprint readers
# Configures PAM to use fprintd for GNOME login, sudo, polkit, and keyring unlock
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable fprintd service
  services.fprintd.enable = true;

  # Configure PAM to use fingerprint authentication
  # Using 'sufficient' means fingerprint OR password works (safer fallback)
  # Note: We use lib.mkForce to override GDM's default false value for login.fprintAuth
  security.pam.services = {
    # GDM login screen - these should work without mkForce
    gdm.fprintAuthorized = true;
    gdm-fingerprint.fprintAuthorized = true;

    # Sudo authentication
    sudo.fprintAuthorized = true;

    # Polkit authentication (for system settings, package installation, etc.)
    polkit-1.fprintAuthorized = true;

    # GNOME Keyring unlock - needs mkForce because GDM module sets it to false
    # This is crucial for automatic keyring unlock after fingerprint login
    login.fprintAuthorized = lib.mkForce true;

    # Screen lock authentication
    gnome-keyring.fprintAuthorized = true;
  };

  # Add fprintd package to system for enrolling fingerprints
  environment.systemPackages = with pkgs; [
    fprintd
  ];
}
