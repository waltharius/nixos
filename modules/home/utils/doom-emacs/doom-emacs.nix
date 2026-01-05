# modules/home/utils/doom-emacs/doom-emacs.nix
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.programs.doom-emacs;
  
  doomDir = cfg.doomConfigDir;
  doomInstallDir = "${config.home.homeDirectory}/.config/emacs-doom";
  
  # Doom Emacs installation script
  installDoom = pkgs.writeShellScript "install-doom" ''
    #!/usr/bin/env bash
    set -e
    
    DOOMDIR="${doomDir}"
    EMACSDIR="${doomInstallDir}"
    
    # Check if Doom is already installed
    if [ ! -d "$EMACSDIR" ]; then
      echo "📥 Installing Doom Emacs to $EMACSDIR..."
      
      # Clone Doom Emacs
      ${pkgs.git}/bin/git clone --depth 1 https://github.com/doomemacs/doomemacs "$EMACSDIR"
      
      # Install Doom (without --no-fonts flag)
      export DOOMDIR="$DOOMDIR"
      "$EMACSDIR/bin/doom" install --no-env
      
      echo "✅ Doom Emacs installed!"
      echo ""
      echo "Next steps:"
      echo "  1. Run: doom sync"
      echo "  2. Run: doom-emacs"
    else
      echo "✅ Doom Emacs already installed at $EMACSDIR"
    fi
  '';
  
  # Wrapper to launch Doom Emacs
  doomEmacsWrapper = pkgs.writeShellScriptBin "doom-emacs" ''
    #!/usr/bin/env bash
    
    DOOMDIR="${doomDir}"
    EMACSDIR="${doomInstallDir}"
    
    # Check if Doom is installed
    if [ ! -d "$EMACSDIR" ]; then
      echo "❌ Doom Emacs not installed yet!"
      echo "Run: doom-install"
      exit 1
    fi
    
    export DOOMDIR="$DOOMDIR"
    export EMACSDIR="$EMACSDIR"
    
    exec "$EMACSDIR/bin/doom" run "$@"
  '';
  
  # Doom CLI wrapper
  doomCliWrapper = pkgs.writeShellScriptBin "doom" ''
    #!/usr/bin/env bash
    
    DOOMDIR="${doomDir}"
    EMACSDIR="${doomInstallDir}"
    
    if [ ! -d "$EMACSDIR" ]; then
      echo "❌ Doom Emacs not installed yet!"
      echo "Run: doom-install"
      exit 1
    fi
    
    export DOOMDIR="$DOOMDIR"
    export EMACSDIR="$EMACSDIR"
    
    exec "$EMACSDIR/bin/doom" "$@"
  '';
  
  # Installation helper
  doomInstallWrapper = pkgs.writeShellScriptBin "doom-install" ''
    #!/usr/bin/env bash
    exec ${installDoom}
  '';
in
{
  options.programs.doom-emacs = {
    enable = mkEnableOption "Doom Emacs (alongside regular Emacs)";
    
    doomConfigDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.config/doom";
      description = "Doom configuration directory (init.el, config.el, packages.el)";
    };
  };

  config = mkIf cfg.enable {
    # Install wrapper scripts
    home.packages = [
      doomEmacsWrapper
      doomCliWrapper
      doomInstallWrapper
      # Dependencies for Doom
      pkgs.git
      pkgs.ripgrep
      pkgs.fd
      pkgs.emacs
    ];

    # Doom configuration files
    home.file."${cfg.doomConfigDir}/init.el".text = ''
      ;;; init.el --- Doom Emacs minimal config for journal -*- lexical-binding: t; -*-

      (doom! :completion
             company
             vertico

             :ui
             doom
             doom-dashboard
             modeline
             ophints
             (popup +defaults)
             vc-gutter
             vi-tilde-fringe
             workspaces

             :editor
             (evil +everywhere)
             file-templates
             fold
             snippets

             :emacs
             dired
             electric
             undo
             vc

             :term
             vterm

             :checkers
             syntax

             :tools
             magit
             lookup
             
             :lang
             emacs-lisp
             markdown
             org

             :config
             (default +bindings +smartparens))
    '';

    home.file."${cfg.doomConfigDir}/config.el".text = ''
      ;;; config.el --- Doom Emacs configuration -*- lexical-binding: t; -*-

      (setq user-full-name "marcin"
            user-mail-address "nixosgitemail.frivolous320@passmail.net")

      (setq doom-theme 'doom-one)
      (setq doom-font (font-spec :family "Hack Nerd Font" :size 14))
      (setq org-directory "~/notes/")

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
        (setq denote-date-prompt-use-org-read-date t)
        (setq denote-date-format "%Y-%m-%d"))

      (load! "+journal")

      (after! org
        (setq org-startup-folded 'overview)
        (setq org-hide-emphasis-markers t)
        (setq org-ellipsis " ▾")
        (setq org-log-done 'time))

      (setq doom-dashboard-banner-file 'official
            +doom-dashboard-functions
            '(doom-dashboard-widget-banner
              doom-dashboard-widget-loaded))
    '';

    home.file."${cfg.doomConfigDir}/packages.el".text = ''
      ;;; packages.el --- Doom Emacs packages -*- lexical-binding: t; -*-

      (package! denote)
    '';

    # Journal functions
    home.file."${cfg.doomConfigDir}/+journal.el".source = ./journal-functions.el;

    # Create notes directory
    home.activation.createNotesDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p ~/notes
    '';

    # Info message
    home.activation.doomEmacInfo = lib.hm.dag.entryAfter ["writeBoundary"] ''
      echo ""
      echo "🎨 Doom Emacs module enabled!"
      echo "   Config dir: ${cfg.doomConfigDir}"
      echo "   Install dir: ${doomInstallDir}"
      echo ""
      echo "📦 First-time setup:"
      echo "   1. Run: doom-install        (installs Doom to ${doomInstallDir})"
      echo "   2. Run: doom sync           (syncs packages)"
      echo "   3. Run: doom-emacs          (launch Doom)"
      echo ""
      echo "⚠️  Note: Your regular 'emacs' command still uses ~/.emacs.d"
      echo "   Doom uses: ${doomInstallDir}"
      echo ""
    '';
  };
}
