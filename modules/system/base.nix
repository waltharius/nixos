{self, ...}: {
  # Enable new python-based nixos-rebuild-ng command
  system.rebuild.enableNg = true;
  users.groups.uinput = {};
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
  '';

  # Embed git commit hash in system label
  system.nixos.label =
    if self ? rev
    then "${config.system.nixos.version}-${builtins.substring 0 8 self.rev}"
    else "${config.system.nixos.version}-dirty";

  # Store full commit hash in system
  environment.etc."nixos-git-revision".text =
    if self ? rev
    then self.rev
    else "uncommitted-changes";
}
