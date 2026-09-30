# modules/home/admin/zoxide.nix
#
# zoxide for every admin account; replaces `cd` (--cmd cd).
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ========================================
  # ZOXIDE - Smarter cd
  # ========================================
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = ["--cmd cd"];
  };
}
