# This file has been superseded by per-host hibernate configurations:
#
#   hosts/workstations/azazel/hibernate.nix
#   hosts/workstations/sukkub/hibernate.nix
#
# Each host now declares its own swap size, HibernateDelaySec, and
# logind sleep policy independently — removing the hostname-based
# conditional that was previously in this file.
# This file is intentionally empty and will be removed in the next
# cleanup pass. Do not import it.
{ ... }: {}
