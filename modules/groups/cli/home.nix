# modules/groups/cli/home.nix
#
# Group `cli`, user part: command-line utilities that make work easier
# but that no admin task depends on. Also available on servers; yazi skips
# its preview helpers there (see ./yazi.nix).
{pkgs, ...}: {
  imports = [
    ./yazi.nix
    ./tmux.nix
  ];

  home.packages = with pkgs; [
    # --- files and search ---
    ripgrep
    fd
    tree
    zip
    unzip
    rsync

    # --- system inspection ---
    btop
    fastfetch
    lsof
    procfd
    usbutils
    pciutils

    # --- network ---
    curl
    wget
    dig
    openssl
  ];
}
