# modules/home/admin/nixvim
#
# Neovim configured with nixvim; part of the admin base (every admin
# account on every host).
{inputs, ...}: {
  programs.nixvim = {
    enable = true;

    # Build nixvim against the system nixpkgs (flake.nix makes nixvim follow
    # it). Setting this explicitly states that choice and silences nixvim's
    # warning about the follows overriding its own pinned nixpkgs.
    nixpkgs.source = inputs.nixpkgs;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Import all sub-configurations INSIDE programs.nixvim
    imports = [
      ./core.nix
      ./plugins.nix
      ./lsp.nix
      ./completion.nix
      ./keymaps.nix
      ./formatting.nix
    ];
  };
}
