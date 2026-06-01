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

  # Embed git commit hash in system label so manual nixos-rebuild calls
  # show exactly which commit was built (visible in nixos-rebuild list-generations).
  #
  # Priority ladder (lower number = higher priority):
  #   lib.mkForce    =  50  (external overrides, e.g. testing)
  #   lib.mkOverride 900    (this definition — beats nixpkgs default)
  #   lib.mkDefault  = 1000 (nixpkgs label.nix fallback: "26.05.YYYYMMDD.rev")
  #
  # Using mkOverride 900 avoids the "conflicting definition values" error
  # that occurs when two mkDefault definitions exist at the same priority.
  system.nixos.label = lib.mkOverride 900 (
    if self ? rev
    then "manual-${builtins.substring 0 8 self.rev}"
    else "manual-dirty"
  );

  # Store full commit hash in /etc for scripting and audit purposes
  environment.etc."nixos-git-revision".text =
    if self ? rev
    then self.rev
    else "uncommitted-changes";
}
