{
  config,
  lib,
  pkg,
  ...
}: {
  programs.starship = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      add_newline = false;

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "bold cyan";
      };

      git_branch = {
        symbol = "";
        style = "bold purple";
      };

      nix_shell = {
        symbol = " ";
        format = "[$symbol$state( ($name))]($style) ";
        style = "bold blue";
      };
    };
  };
}
