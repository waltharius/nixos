# modules/home/admin/starship.nix
#
# Prompt shared by every admin account. Outside workstations the host name
# is always shown (in red), so it is obvious which machine a shell is on.
{
  lib,
  host,
  ...
}: {
  programs.starship = {
    enable = true;
    enableBashIntegration = true;

    settings =
      {
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
      }
      // lib.optionalAttrs (host.class != "workstation") {
        hostname = {
          ssh_only = false;
          format = "[@$hostname](bold red):";
        };
      };
  };
}
