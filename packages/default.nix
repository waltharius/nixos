{pkgs, ...}: {
  rebuild-and-diff = pkgs.callPackage ./rebuild-and-diff {};

  # Add more custom packages (scripts) here in the future.
  # Scripts should be added to ./packages/<script_folder> folder inside this repository
  # and called via ./<script_folder> for example:
  # my-script = pkgs.callPackage ./my-script { };
}
