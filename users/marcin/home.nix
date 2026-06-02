# users/marcin/home.nix
#
# Entry point for Home Manager configuration of user marcin.
#
# This file is intentionally minimal. It sets the mandatory HM identity
# options and delegates everything else to focused modules:
#
#   users/marcin/base/      — configuration that is identical on every host
#   users/marcin/profiles/  — configuration that differs per host
#   modules/                — reusable modules shared across users/hosts
#
# HOW TO ADD A NEW HOST
# ---------------------
# 1. Create users/marcin/profiles/<hostname>.nix (copy sukkub.nix as a
#    starting point).
# 2. Set marcin.desktop to the DE(s) you want active on that host.
# 3. Add the profile to the imports list below using the same pattern.
# That is all — no other file needs to change.
{
  config,
  pkgs,
  lib,
  hostname,
  customPkgs ? {},
  pkgs-unstable,
  ...
}: {
  home.username      = "marcin";
  home.homeDirectory = "/home/marcin";
  home.stateVersion  = "25.11";

  programs.home-manager.enable = true;

  sops = {
    age.keyFile    = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/ssh.yaml;
  };

  imports = [
    # --- shared service / utility modules (modules/) ---
    ../../modules/services/ssh.nix
    ../../modules/services/ssh-askpass.nix
    ../../modules/utils/yazi.nix
    ../../modules/utils/nixvim
    ../../modules/home/tools/zoxide.nix
    ../../modules/home/tools/atuin.nix
    ../../modules/home/tools/buku.nix
    ../../modules/home/shell/bash.nix
    ../../modules/home/shell/starship.nix
    ../../modules/home/terminal/tmux.nix
    ../../modules/home/desktop/gnome.nix

    # --- base config (identical on every host) ---
    ./base/git.nix
    ./base/fonts.nix
    ./base/packages.nix
    ./base/environment.nix
    ./base/nextcloud.nix
    ./base/autostart.nix
    ./base/solaar.nix
    ./base/desktop-extensions.nix

    # --- per-host profile ---
  ] ++ (
    if hostname == "azazel"      then [ ./profiles/azazel.nix ]
    else if hostname == "sukkub" then [ ./profiles/sukkub.nix ]
    else []
  );
}
