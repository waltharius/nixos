# This file has been superseded by per-host TLP configurations:
#
#   hosts/workstations/azazel/tlp.nix
#   hosts/workstations/sukkub/tlp.nix
#
# Each host now declares its own TLP settings to allow independent
# tuning (USB blacklist, NVIDIA RUNTIME_PM blacklist, etc.).
# This file is intentionally empty and will be removed in the next
# cleanup pass. Do not import it.
{ ... }: {}
