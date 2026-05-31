{
  self,
  config,
  lib,
  ...
}: {
  # NOTE: system.rebuild.enableNg was removed in 26.05.
  # The Python-based nixos-rebuild is now the only implementation.
  # The option has been deleted — nothing to configure here.

  users.groups.uinput = {};
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
  '';

  # Embed git commit hash in system label (set via auto-upgrade.nix for
  # scheduled rebuilds; this provides a fallback for manual nixos-rebuild
  # that shows the git rev so you know exactly what was built).
  #
  # Priority: auto-upgrade.nix uses lib.mkForce so it wins during automated
  # runs; manual builds fall through to this mkDefault which shows the rev.
  system.nixos.label = lib.mkDefault (
    if self ? rev
    then "manual-${builtins.substring 0 8 self.rev}"
    else "manual-dirty"
  );

  # Store full commit hash in system
  environment.etc."nixos-git-revision".text =
    if self ? rev
    then self.rev
    else "uncommitted-changes";
}
