# users/marcin/home/packages.nix
#
# marcin's personal applications: programs no group covers because only
# marcin uses them. Everything else comes from the groups in
# hosts/inventory.nix.
{
  pkgs,
  customPkgs,
  ...
}: {
  home.packages = with pkgs; [
    # File manager (PCManFM-Qt with a fix, see packages/pcmanfm-qt-fixed)
    customPkgs.pcmanfm-qt-fixed
    lxqt.libfm-qt

    # Password manager (KeePass format)
    gnome-secrets

    # File sync
    nextcloud-client
    rclone
    rclone-ui

    # Remote desktop to the Windows VM (see rdp-win11 in ./shell.nix)
    freerdp
    # secret-tool, used by rdp-win11
    libsecret
  ];
}
