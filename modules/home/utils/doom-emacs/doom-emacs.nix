# modules/home/utils/doom-emacs/doom-emacs.nix
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.programs.doom-emacs;
in
{
  options.programs.doom-emacs = {
    enable = mkEnableOption "Doom Emacs (alongside regular Emacs)";
    
    doomConfigDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.config/doom";
      description = "Doom configuration directory (init.el, config.el, packages.el)";
    };

    doomInstallDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.config/emacs-doom";
      description = "Doom installation directory (where Doom installs packages/cache)";
    };

    emacsPackage = mkOption {
      type = types.package;
      default = pkgs.emacs;  # Use standard emacs package
      description = "Emacs package to use for Doom";
    };
  };

  config = mkIf cfg.enable {
    # Install Doom Emacs wrapper scripts
    home.packages = [
      # Doom Emacs launcher
      (pkgs.writeShellScriptBin "doom-emacs" ''
        #!/usr/bin/env bash
        # Launch Doom Emacs with isolated directories
        # DOOMDIR = config files (init.el, config.el, packages.el)
        # EMACSDIR = installation dir (packages, cache, state)
        export DOOMDIR="${cfg.doomConfigDir}"
        export EMACSDIR="${cfg.doomInstallDir}"
        
        # First run setup check
        if [ ! -d "$EMACSDIR" ]; then
          echo "🚀 First run detected - Doom needs to sync packages..."
          echo "After Emacs starts, run: M-x doom/reload"
          echo ""
        fi
        
        exec ${cfg.emacsPackage}/bin/emacs "$@"
      '')

      # Doom CLI wrapper (for doom sync, doom doctor, etc.)
      (pkgs.writeShellScriptBin "doom" ''
        #!/usr/bin/env bash
        # Doom CLI wrapper for isolated installation
        export DOOMDIR="${cfg.doomConfigDir}"
        export EMACSDIR="${cfg.doomInstallDir}"
        
        # Run Doom CLI (if Doom is installed)
        if [ -f "$EMACSDIR/bin/doom" ]; then
          exec "$EMACSDIR/bin/doom" "$@"
        else
          echo "❌ Doom not installed yet in $EMACSDIR"
          echo "Launch 'doom-emacs' first to initialize Doom"
          exit 1
        fi
      '')
    ];

    # Doom configuration files
    home.file."${cfg.doomConfigDir}/init.el".text = ''
      ;;; init.el --- Doom Emacs minimal config for journal testing -*- lexical-binding: t; -*-
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
      ;;; config.el --- Doom Emacs configuration for journal testing -*- lexical-binding: t; -*-

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
      echo "   Install dir: ${cfg.doomInstallDir}"
      echo ""
      echo "📝 Usage:"
      echo "   doom-emacs     → Launch Doom Emacs"
      echo "   doom sync      → Sync packages (run after config changes)"
      echo "   doom doctor    → Check installation health"
      echo ""
      echo "🗒️  Journal keybindings (in Doom):"
      echo "   SPC n j  → Create/open today's journal"
      echo "   SPC n J  → Create journal with custom date"
      echo "   SPC n R  → Rename based on frontmatter"
      echo "   SPC n t  → Manage tags"
      echo ""
    '';
  };
}
