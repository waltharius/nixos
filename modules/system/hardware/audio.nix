# modules/system/hardware/audio.nix
#
# PipeWire audio stack — desktop-environment-agnostic.
#
# Extracted from modules/system/desktop/gnome.nix so that any future
# compositor (niri, Hyprland, etc.) can include audio without depending
# on GNOME. The NixOS module system merges option sets from all imported
# modules, so splitting this out causes no duplication or conflicts.
#
# PulseAudio is explicitly disabled because PipeWire and PulseAudio share
# the same user-session audio slot and cannot run simultaneously. PipeWire
# provides a drop-in PulseAudio compatibility layer via pulse.enable, so
# all applications built against libpulse continue to work unchanged.
#
# security.rtkit grants PipeWire real-time CPU scheduling priority through
# the rtkit system daemon. Without it, audio may stutter under CPU load
# because the kernel treats audio threads as ordinary low-priority tasks.
#
# alsa.support32Bit is required for 32-bit applications (Steam, Wine) that
# use ALSA directly rather than going through the PulseAudio compatibility
# layer.
{ ... }: {
  services.pulseaudio.enable = false;

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable = true;  # uncomment if pro-audio JACK applications are needed
  };
}
