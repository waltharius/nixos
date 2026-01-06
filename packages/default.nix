{pkgs, ...}: {
  # 'callPackage' is better than 'import' because it
  # - reads package file's function signature
  # - use 'bultins.functionArgs' to discover proper arguments if needed
  # - automatically passes matching attributes from pkgs to the package
  # - only requires to explicitly pass an arguments that override defaults or not in pkgs
  # Links for more reading:
  # 1. https://nixos.org/guides/nix-pills/13-callpackage-design-pattern.html
  # 2. https://nix.dev/tutorials/callpackage.html
  # 3. https://book.divnix.com/ch05-03-imports-and-callpackage.html

  rebuild-and-diff = pkgs.callPackage ./rebuild-and-diff {};
  solaar-extension = pkgs.callPackage ./solaar-extension {};
  solaar-stable = pkgs.callPackage ./solaar {};
  track-package = pkgs.callPackage ./track-package {};
  track-package-deps = pkgs.callPackage ./track-package-deps {};
  track-package-py = pkgs.callPackage ./track-package-py {};
  track-package-simple = pkgs.callPackage ./track-package-simple {};

  # Add more custom packages (scripts) here in the future.
  # Scripts should be added to ./packages/<script_folder> folder inside this repository
  # and called via ./<script_folder> for example:
  # my-script = pkgs.callPackage ./my-script { };
}
