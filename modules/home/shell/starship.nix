# modules/home/shell/starship.nix
# Starship prompt with server/laptop variants
{
  lib,
  userConfig ? {},
  ...
}: let
  isServer = userConfig.isServer or false;
in {
  programs.starship = {
    enable = true;
    enableBashIntegration = true;

    settings =
      if isServer
      then {
        # ==========================================
        # SERVER PROMPT - Red indicator, show hostname
        # ==========================================
        add_newline = false;

        format = lib.concatStrings [
          "[](bold red)"
          "[ SERVER ](bg:red fg:black)"
          "[](fg:red bg:blue)"
          "[ $hostname ](bg:blue fg:white)"
          "[](fg:blue bg:cyan)"
          "[ $directory ](bg:cyan fg:black)"
          "[](fg:cyan)"
          "$git_branch"
          "$nix_shell"
          "\n$character" # Newline before prompt
        ];

        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };

        hostname = {
          ssh_only = false;
          format = "[$hostname]($style)";
          style = "bold white";
        };

        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
          style = "bold black";
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
      else {
        # ==========================================
        # LAPTOP PROMPT - Your current config, no hostname
        # ==========================================
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
