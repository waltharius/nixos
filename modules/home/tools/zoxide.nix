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
