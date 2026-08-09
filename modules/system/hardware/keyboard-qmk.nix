# modules/system/hardware/keyboard-qmk.nix
#
# Raw HID access for QMK/VIA keyboards (NuPhy Air75 V2 and other NuPhy
# models, USB vendor ID 0x19f5).
#
# WHY THIS IS NEEDED
# ------------------
# VIA — both the web configurator at https://usevia.app (WebHID) and the
# desktop app — talks to the keyboard over /dev/hidrawN. By default those
# nodes are root-only, so the browser gets EACCES and the keyboard never
# shows up in the "Authorize device" picker.
#
# WHY NOT services.udev.extraRules
# --------------------------------
# extraRules is written to 99-local.rules. TAG+="uaccess" is consumed by
# systemd's 73-seat-late.rules, which has already run by then, so the tag
# would be silently ignored. The rule must therefore ship in a package with
# a filename sorting before 73-. See:
#   https://github.com/NixOS/nixpkgs/issues/308681
#   https://github.com/NixOS/nixpkgs/issues/210856
#
# WHY NOT hardware.keyboard.qmk.enable
# ------------------------------------
# That option pulls in pkgs.qmk-udev-rules (50-qmk.rules), which contains
# a blanket rule:
#     KERNEL=="hidraw*", MODE="0660", GROUP="plugdev", TAG+="uaccess", ...
# i.e. it opens *every* hidraw device on the machine to the seat user and
# to every member of plugdev. This module scopes access to one vendor ID
# instead. Enable hardware.keyboard.qmk.enable additionally only if you
# need the bootloader/DFU rules for flashing firmware.
{ pkgs, ... }:
let
  # Priority 60 so the uaccess tag is set before 73-seat-late.rules runs.
  nuphyUdevRules = pkgs.writeTextFile {
    name = "nuphy-udev-rules";
    destination = "/lib/udev/rules.d/60-nuphy.rules";
    text = ''
      # NuPhy keyboards and 2.4 GHz dongles (USB vendor 0x19f5).
      # uaccess attaches a POSIX ACL for the user of the active local
      # session only — no world-readable mode, no static group membership.
      # Read access to a keyboard's hidraw node is effectively a keylogger,
      # so this is deliberately narrower than MODE="0666".
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", TAG+="uaccess"
    '';
  };
in
{
  services.udev.packages = [ nuphyUdevRules ];

  # Optional: the standalone VIA desktop app as a fallback if the web
  # configurator misbehaves. It is an unfree-redistributable AppImage.
  # NOTE: do NOT add pkgs.via to services.udev.packages — its bundled rule
  # is MODE="0666" on every hidraw device.
  # environment.systemPackages = [ pkgs.via ];
}
