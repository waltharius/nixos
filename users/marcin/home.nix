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
#
# HOW TO ADD A NEW DESKTOP ENVIRONMENT MODULE
# -------------------------------------------
# Desktop environment HM modules fall into two categories:
#
# GLOBAL DEs (e.g. gnome.nix):
#   The module depends only on standard HM/nixpkgs options. Import it
#   statically here. It guards itself with lib.mkIf based on marcin.desktop.
#
# HOST-SPECIFIC DEs (e.g. niri.nix):
#   The module depends on options provided by an external flake HM module
#   (e.g. niri-flake.homeModules.niri). Do NOT import it here — importing
#   it globally would break hosts that don't load that flake module.
#   Instead, load it in the host's NixOS profile.nix:
#
#     home-manager.users.marcin.imports = [
#       ../../../modules/home/desktop/niri.nix
#     ];
#
#   The corresponding NixOS module (modules/system/niri.nix) is self-
#   contained and imports niri-flake.nixosModules.niri itself, which
#   auto-injects homeModules.niri for home-manager — so niri.nix's
#   options will be available when the HM module is loaded this way.
{
  config,
  pkgs,
  lib,
  hostname,
  customPkgs ? {},
  pkgs-unstable,
  ...
}: {
  home.username = "marcin";
  home.homeDirectory = "/home/marcin";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/ssh.yaml;
  };

  imports =
    [
      # --- shared service / utility modules ---
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

      # --- desktop environment HM modules (global) ---
      # Only modules that depend solely on standard HM/nixpkgs options.
      # Host-specific DE modules (niri.nix) are loaded via
      # home-manager.users.marcin.imports in the host's profile.nix.
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
    ]
    ++ (
      if hostname == "azazel"
      then [./profiles/azazel.nix]
      else if hostname == "sukkub"
      then [./profiles/sukkub.nix]
      else []
    );
}
