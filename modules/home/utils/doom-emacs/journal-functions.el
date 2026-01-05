;;; +journal.el --- Journal functions ported from regular Emacs -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2026 marcin
;;
;; This file contains journal creation functions ported from your main Emacs
;; configuration at https://github.com/waltharius/emacs
;;
;; Features ported:
;; - my/denote-journal (C-c n j / SPC n j)
;; - my/denote-journal-date (C-c n J / SPC n J)
;; - Well-being property tracking
;; - Rename based on frontmatter (SPC n R)
;; - Tag management (SPC n t)
;;
;;; Code:

(defvar my-notes-dir (expand-file-name "~/notes/")
  "Directory for notes (same as regular Emacs).")

;; ============================================================
;; PORT: Journal creation (C-c n j)
;; ============================================================

(defun my/doom-journal ()
  "Create or open journal for today.
This is a direct port from your main Emacs config.

Creates journal with:
- Title: YYYY-MM-DD Journal
- Date property
- :journal: tag
- Well-being property (empty, to fill manually)
- First entry with current time"
  (interactive)
  (let* ((today (format-time-string "%Y-%m-%d"))
         (time-now (format-time-string "%H:%M"))
         (journal-pattern (concat "--" today "-journal"))
         (existing-journal nil))
    
    ;; Search for existing journal
    (dolist (file (directory-files my-notes-dir t "\\.org$"))
      (when (string-match-p journal-pattern (file-name-nondirectory file))
        (setq existing-journal file)))
    
    (if existing-journal
        ;; Journal exists - open and add entry
        (progn
          (find-file existing-journal)
          (goto-char (point-max))
          
          ;; Smart spacing (exactly one blank line)
          (save-excursion
            (goto-char (point-max))
            (skip-chars-backward " \t\n")
            (delete-region (point) (point-max)))
          
          (goto-char (point-max))
          (insert "\n\n")
          (insert (format "* %s\n" time-now))
          (message "Added entry to journal"))
      
      ;; Create new journal
      (let* ((id (format-time-string "%Y%m%dT%H%M%S"))
             (slug (replace-regexp-in-string "[^[:alnum:]]" "-" (downcase (format "%s-journal" today))))
             (filename (format "%s--%s__journal.org" id slug))
             (filepath (expand-file-name filename my-notes-dir)))
        
        (find-file filepath)
        
        ;; Frontmatter (EXACT format from your main Emacs)
        (insert (format "#+title:      %s Journal\n" today))
        (insert (format "#+date:       [%s]\n" (format-time-string "%Y-%m-%d %a %H:%M")))
        (insert "#+filetags:   :journal:\n")
        (insert (format "#+identifier: %s\n" id))
        
        ;; Properties (with well-being)
        (insert ":PROPERTIES:\n")
        (insert ":well-being:  \n")  ; Empty - fill manually
        (insert ":END:\n\n")
        
        ;; First entry
        (insert (format "* Ksi\u0105\u017cenice (%s)\n" time-now))
        
        ;; Auto-save immediately
        (save-buffer)
        (message "Created new journal")))))

;; ============================================================
;; PORT: Journal with custom date (C-c n J)
;; ============================================================

(defun my/doom-journal-date ()
  "Create journal with selected date (for migration of old entries).
This is a direct port from your main Emacs config."
  (interactive)
  (let* ((date-input (org-read-date nil nil nil "Data wpisu: "))
         (parsed-time (org-parse-time-string date-input))
         (date-formatted (format-time-string "%Y-%m-%d"
                                              (apply 'encode-time parsed-time)))
         (title (read-string "Tytu\u0142 (Enter = domy\u015blny): "
                             (format "%s Journal" date-formatted)))
         (keywords-input (read-string "Tagi (Enter = 'journal'): " "journal"))
         (keywords (split-string keywords-input))
         (time-now (format-time-string "%H:%M")))
    
    (let* ((id (format-time-string "%Y%m%dT%H%M%S" (apply 'encode-time parsed-time)))
           (slug (replace-regexp-in-string "[^[:alnum:]]+" "-" (downcase title)))
           (keywords-slug (mapconcat (lambda (k)
                                       (replace-regexp-in-string
                                        "[^[:alnum:]]+" "-" (downcase k)))
                                     keywords "_"))
           (filename (format "%s--%s__%s.org" id slug keywords-slug))
           (filepath (expand-file-name filename my-notes-dir)))
      
      (find-file filepath)
      (insert (format "#+title:      %s\n" title))
      (insert (format "#+date:       %s\n"
                      (format-time-string "[%Y-%m-%d %a %H:%M]"
                                          (apply 'encode-time parsed-time))))
      (insert (format "#+filetags:   :%s:\n" (mapconcat 'identity keywords ":")))
      (insert (format "#+identifier: %s\n\n" id))
      
      ;; Properties with well-being
      (insert ":PROPERTIES:\n")
      (insert ":well-being:  \n")
      (insert ":END:\n\n")
      
      (insert (format "* Ksi\u0105\u017cenice (%s)\n\n" time-now))
      (insert "* Powi\u0105zane notatki\n")
      (goto-char (point-min))
      (search-forward "* Ksi\u0105\u017cenice")
      (end-of-line)
      (forward-line 1)
      (message "Utworzono journal z dat\u0105 %s" date-formatted))))

;; ============================================================
;; PORT: Well-being entry (for future use)
;; ============================================================

(defun my/doom-wellbeing-entry ()
  "Add well-being score (1-10) to today's journal.
This is a simplified port - full wellbeing module not included yet."
  (interactive)
  (let* ((score (read-number "Well-being (1-10): "))
         (keywords (read-string "Keywords (optional, space-separated): " nil nil "")))
    
    ;; Validate score
    (unless (and (>= score 1) (<= score 10))
      (user-error "Score must be between 1-10!"))
    
    ;; Find today's journal
    (let* ((today (format-time-string "%Y-%m-%d"))
           (journal-pattern (concat "--" today ".*journal"))
           (existing-journal nil))
      
      (dolist (file (directory-files my-notes-dir t "\\.org$"))
        (when (string-match-p journal-pattern (file-name-nondirectory file))
          (setq existing-journal file)))
      
      (if existing-journal
          (progn
            (find-file existing-journal)
            (goto-char (point-min))
            
            ;; Update well-being property
            (if (re-search-forward "^:PROPERTIES:" nil t)
                (let* ((props-start (match-beginning 0))
                       (props-end (save-excursion
                                    (goto-char props-start)
                                    (re-search-forward "^:END:" nil t)
                                    (point))))
                  (goto-char props-start)
                  (forward-line 1)
                  
                  (if (re-search-forward "^:well-being:" props-end t)
                      ;; Update existing
                      (progn
                        (beginning-of-line)
                        (kill-line)
                        (insert (format ":well-being: %d" score)))
                    ;; Add new
                    (goto-char props-end)
                    (forward-line -1)
                    (end-of-line)
                    (insert (format "\n:well-being: %d" score))))
              
              ;; No properties - create
              (goto-char (point-min))
              (when (re-search-forward "^#\\+identifier:" nil t)
                (forward-line 1)
                (insert ":PROPERTIES:\n")
                (insert (format ":well-being: %d\n" score))
                (insert ":END:\n")))
            
            ;; Add keywords if provided
            (when (and keywords (not (string-empty-p keywords)))
              (goto-char (point-max))
              (unless (bolp) (insert "\n"))
              (insert "\n** Well-being context\n")
              (dolist (kw (split-string keywords))
                (insert (format "#%s " kw)))
              (insert "\n"))
            
            (save-buffer)
            (message "\u2713 Well-being: %d %s" score
                     (if (string-empty-p keywords) ""
                       (concat "| Keywords: " keywords))))
        
        (user-error "No journal for today! Create journal first with SPC n j")))))

;; ============================================================
;; DOOM KEYBINDINGS
;; ============================================================

(after! denote
  ;; Map to Doom's leader key (SPC in normal mode)
  (map! :leader
        :desc "Notes menu" :n "n" nil  ; Clear default binding
        
        (:prefix ("n" . "notes")
         :desc "Journal today" "j" #'my/doom-journal
         :desc "Journal date" "J" #'my/doom-journal-date
         :desc "Well-being entry" "w" #'my/doom-wellbeing-entry
         :desc "Rename from frontmatter" "R" #'denote-rename-file-using-front-matter
         :desc "Rename tags" "t" #'denote-rename-file-keywords
         :desc "Add links" "l" #'denote-add-links
         :desc "Insert link" "i" #'denote-link
         :desc "Find note" "f" #'denote-open-or-create)))

;; ============================================================
;; HELPER: Insert current time (for manual entries)
;; ============================================================

(defun my/doom-insert-time ()
  "Insert current time in HH:MM format."
  (interactive)
  (insert (format-time-string "%H:%M")))

;; Add to keybindings
(after! org
  (map! :map org-mode-map
        :localleader
        :desc "Insert time" "t" #'my/doom-insert-time))

;; ============================================================
;; INFO MESSAGE
;; ============================================================

(message "\u2705 Journal functions loaded! Keybindings: SPC n j (today), SPC n J (date)")

(provide '+journal)
;;; +journal.el ends here
