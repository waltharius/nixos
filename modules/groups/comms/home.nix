# modules/groups/comms/home.nix
#
# Group `comms`, user part: messaging and e-mail.
{pkgs, ...}: {
  home.packages = with pkgs; [
    signal-desktop
    thunderbird-latest
  ];
}
