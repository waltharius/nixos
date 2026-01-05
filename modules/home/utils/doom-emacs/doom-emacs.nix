# modules/home/utils/doom-emacs/doom-emacs.nix
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.programs.doom-emacs;
  
  # Build Doom Emacs from the flake input
  doom-emacs-pkg = inputs.nix-doom-emacs-unstraightened.packages.${pkgs.system}.default.override {
    doomDir = cfg.doomConfigDir;
    emacsPackage = cfg.emacsPackage;
  };
in
{
  options.programs.doom-emacs = {
    enable = mkEnableOption "Doom Emacs (alongside regular Emacs)";
    
    doomConfigDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.config/doom";
      description = "Doom configuration directory (init.el, config.el, packages.el)";
    };

    emacsPackage = mkOption {
      type = types.package;
      default = pkgs.emacs;
      description = "Emacs package to use for Doom";
    };
  };

  config = mkIf cfg.enable {
    # Install the actual Doom Emacs package
    home.packages = [
      doom-emacs-pkg
    ];

    # Create wrapper for easier invocation
    home.file.".local/bin/doom-emacs" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Launch Doom Emacs with proper DOOMDIR
        export DOOMDIR="${cfg.doomConfigDir}"
        exec ${doom-emacs-pkg}/bin/emacs "$@"
      '';
    };

    # Doom configuration files
    home.file."${cfg.doomConfigDir}/init.el".text = ''
      ;;; init.el --- Doom Emacs minimal config for journal -*- lexical-binding: t; -*-
      ;;
      ;; This is a MINIMAL Doom config for testing journal features
      ;; Isolated from your main Emacs setup in ~/.emacs.d
      ;;
      ;; Author: marcin

      (doom! :completion
             company           ; text completion
             vertico           ; search/filtering

             :ui
             doom              ; doom theme
             doom-dashboard    ; startup screen
             modeline          ; status bar
             ophints           ; highlight region
             (popup +defaults) ; popup rules
             vc-gutter         ; git diff in gutter
             vi-tilde-fringe   ; fringe tildes for empty lines
             workspaces        ; tab-like workspaces

             :editor
             (evil +everywhere) ; vim emulation
             file-templates     ; auto-templates
             fold               ; code folding
             snippets           ; yasnippet

             :emacs
             dired             ; file manager
             electric          ; smart indentation
             undo              ; undo/redo
             vc                ; version control

             :term
             vterm             ; terminal emulator

             :checkers
             syntax            ; syntax checking

             :tools
             magit             ; git interface
             lookup            ; navigate code/docs
             
             :lang
             emacs-lisp        ; elisp support
             markdown          ; markdown support
             org               ; org-mode (CRITICAL for journal!)

             :config
             (default +bindings +smartparens))
    '';

    home.file."${cfg.doomConfigDir}/config.el".text = ''
      ;;; config.el --- Doom Emacs configuration for journal -*- lexical-binding: t; -*-

      ;; User info (from your main Emacs config)
      (setq user-full-name "marcin"
            user-mail-address "nixosgitemail.frivolous320@passmail.net")

      ;; Theme
      (setq doom-theme 'doom-one)

      ;; Font (same as your main Emacs - Hack Nerd Font)
      (setq doom-font (font-spec :family "Hack Nerd Font" :size 14))

      ;; Org directory (SAME as your regular Emacs)
      (setq org-directory "~/notes/")

      ;; Denote configuration (ported from your main Emacs)
      (use-package! denote
        :config
        (setq denote-directory (expand-file-name "~/notes/"))
        (setq denote-known-keywords '("journal" "zettel" "osoba" "projekt" "lektura"))
        (setq denote-infer-keywords t)
        (setq denote-sort-keywords t)
        (setq denote-file-type 'org)
        (setq denote-prompts '(title keywords))
        (setq denote-excluded-directories-regexp nil)
        (setq denote-excluded-keywords-regexp nil)
        
        ;; Date format (same as your main config)
        (setq denote-date-prompt-use-org-read-date t)
        (setq denote-date-format "%Y-%m-%d"))

      ;; Load journal functions (ported from your main Emacs)
      (load! "+journal")

      ;; Org-mode settings (basic, matching your main config)
      (after! org
        (setq org-startup-folded 'overview)
        (setq org-hide-emphasis-markers t)
        (setq org-ellipsis " ▾")
        (setq org-log-done 'time))

      ;; Dashboard customization
      (setq doom-dashboard-banner-file 'official
            +doom-dashboard-functions
            '(doom-dashboard-widget-banner
              doom-dashboard-widget-loaded))
    '';

    home.file."${cfg.doomConfigDir}/packages.el".text = ''
      ;;; packages.el --- Doom Emacs packages -*- lexical-binding: t; -*-

      ;; Denote - for journal/note management (CRITICAL)
      (package! denote)
    '';

    # Journal functions ported from main Emacs
    home.file."${cfg.doomConfigDir}/+journal.el".source = ./journal-functions.el;

    # Create notes directory if it doesn't exist
    home.activation.createNotesDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p ~/notes
    '';

    # Inform user about setup
    home.activation.doomEmacInfo = lib.hm.dag.entryAfter ["writeBoundary"] ''
      echo ""
      echo "🎨 Doom Emacs installed!"
      echo "   Config dir:  ${cfg.doomConfigDir}"
      echo "   Package:     ${doom-emacs-pkg}"
      echo ""
      echo "📝 Usage:"
      echo "   doom-emacs     → Launch Doom Emacs"
      echo "   doom sync      → Sync packages (use from \$DOOMDIR)"
      echo ""
      echo "🗂️  Journal keybindings (in Doom):"
      echo "   SPC n j  → Create/open today's journal"
      echo "   SPC n J  → Create journal with custom date"
      echo "   SPC n R  → Rename based on frontmatter"
      echo "   SPC n t  → Manage tags"
      echo ""
    '';
  };
}
