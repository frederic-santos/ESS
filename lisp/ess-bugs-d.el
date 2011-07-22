;;; ess-bugs-d.el -- ESS[BUGS] dialect

;; Copyright (C) 2008-2011 Rodney Sparapani

;; Original Author: Rodney Sparapani
;; Created: 13 March 2008
;; Maintainers: ESS-help <ess-help@r-project.org>

;; This file is part of ESS

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
;;
;; In short: you may use this code any way you like, as long as you
;; don't charge money for it, remove this notice, or hold anyone liable
;; for its results.

;; Code:

(require 'ess-bugs-l)
(require 'ess-utils)
(require 'ess-inf)

(setq auto-mode-alist
    (append '(("\\.[bB][uU][gG]\\'" . ess-bugs-mode)) auto-mode-alist))

(defvar ess-bugs-command "OpenBUGS" "Default BUGS program in PATH.")
(make-local-variable 'ess-bugs-command)

(defvar ess-bugs-monitor '("") "Default list of variables to monitor.")
(make-local-variable 'ess-bugs-monitor)

(defvar ess-bugs-thin 1 "Default thinning parameter.")
(make-local-variable 'ess-bugs-thin)

(defvar ess-bugs-chains 1 "Default number of chains.")
(make-local-variable 'ess-bugs-chains)

(defvar ess-bugs-burnin 10000 "Default burn-in.")
(make-local-variable 'ess-bugs-burnin)

(defvar ess-bugs-update 10000 "Default number of updates after burnin.")
(make-local-variable 'ess-bugs-update)

(defvar ess-bugs-system nil "Default whether BUGS recognizes the system command.")

(defvar ess-bugs-font-lock-keywords
    (list
	;; .bug files
	(cons "#.*\n"			font-lock-comment-face)

	(cons "^[ \t]*\\(model\\|var\\)\\>"
					font-lock-keyword-face)

	(cons (concat "\\<d\\(bern\\|beta\\|bin\\|cat\\|chisq\\|"
		"dexp\\|dirch\\|exp\\|\\(gen[.]\\)?gamma\\|hyper\\|"
		"interval\\|lnorm\\|logis\\|mnorm\\|mt\\|multi\\|"
		"negbin\\|norm\\(mix\\)?\\|par\\|pois\\|sum\\|t\\|"
		"unif\\|weib\\|wish\\)[ \t\n]*(")
					font-lock-constant-face)

	(cons (concat "\\<\\(abs\\|cos\\|dim\\|\\(i\\)?cloglog\\|equals\\|"
		"exp\\|for\\|inprod\\|interp[.]line\\|inverse\\|length\\|"
		"\\(i\\)?logit\\|logdet\\|logfact\\|loggam\\|max\\|mean\\|"
		"mexp\\|min\\|phi\\|pow\\|probit\\|prod\\|rank\\|round\\|"
		"sd\\|sin\\|sort\\|sqrt\\|step\\|sum\\|t\\|trunc\\|T\\)[ \t\n]*(")
					font-lock-function-name-face)

	;; .bmd files
	(cons (concat (regexp-opt '(
				    "dicClear" "dicSet" "dicStats"
				    "infoMemory" "infoModules" "infoNodeMethods" 
				    "infoNodeTypes" "infoNodeValues"
				    "infoUpdatersbyDepth" "infoUpdatersbyName"
				    "modelCheck" "modelCompile" "modelData" 
				    "modelDisable" "modelEnable" "modelGenInits" 
				    "modelInits" "modelPrecision" "modelQuit" 
				    "modelSaveState" "modelSetAP" "modelSetIts" 
				    "modelSetOR" "modelSetRN" "modelUpdate" 
				    "ranksClear" "ranksSet" "ranksStats"
				    "samplesAutoC" "samplesBgr" "samplesCoda" 
				    "samplesDensity" "samplesHistory" "samplesSet" 
				    "sampleStats" "samplesThin"
				    "summaryClear" "summarySet" "summaryStats"
				    ) 'words) "(")
	     font-lock-function-name-face)

	(cons (concat (regexp-opt '("Local Variables" "End") 'words) ":")
	     font-lock-keyword-face)
    )
    "ESS[BUGS]: Font lock keywords."
)

(defun ess-bugs-switch-to-suffix (suffix &optional bugs-chains bugs-monitor bugs-thin
   bugs-burnin bugs-update)
   "ESS[BUGS]: Switch to file with suffix."
   (find-file (concat ess-bugs-file-dir ess-bugs-file-root suffix))

   (if (equal 0 (buffer-size)) (progn
	(if (equal ".bug" suffix) (progn
	    ;(insert "var ;\n")
	    (insert "model {\n")
            (insert "    for (i in 1:N) {\n    \n")
            (insert "    }\n")
            (insert "}\n")
	    (insert "#Local Variables" ":\n")
;	    (insert "#enable-local-variables: :all\n")
	    (insert "#ess-bugs-chains:1\n")
	    (insert "#ess-bugs-monitor:(\"\")\n")
	    (insert "#ess-bugs-thin:1\n")
	    (insert "#ess-bugs-burnin:10000\n")
	    (insert "#ess-bugs-update:10000\n")
	    (insert "#End:\n")
	))

	(if (equal ".bmd" suffix) (let
	    ((ess-bugs-temp-chains "") (ess-bugs-temp-monitor "") (ess-bugs-temp-chain ""))

	    (if bugs-chains (setq ess-bugs-chains bugs-chains))
	    (if bugs-monitor (setq ess-bugs-monitor bugs-monitor))
	    (if bugs-thin (setq ess-bugs-thin bugs-thin))

	    (setq ess-bugs-temp-chains
		(concat "modelCompile(" (format "%d" ess-bugs-chains) ")\n"))

	    (setq bugs-chains ess-bugs-chains)

	    (while (< 0 bugs-chains)
		(setq ess-bugs-temp-chains
		    (concat ess-bugs-temp-chains
			"modelInits('" ess-bugs-file-root
			".##" (format "%d" bugs-chains) "', "
			(format "%d" bugs-chains) ")\n"))
		(setq bugs-chains (- bugs-chains 1)))

	    (setq ess-bugs-temp-monitor "")

		(while (and (listp ess-bugs-monitor) (consp ess-bugs-monitor))
		    (if (not (string-equal "" (car ess-bugs-monitor)))
			(setq ess-bugs-temp-monitor
			    (concat ess-bugs-temp-monitor "samplesSet('"
				(car ess-bugs-monitor) 
				;", thin(" (format "%d" ess-bugs-thin) 
				"')\n")))
		    (setq ess-bugs-monitor (cdr ess-bugs-monitor)))

	    (insert "modelCheck('" ess-bugs-file-root ".bug')\n")
	    (insert "modelData('" ess-bugs-file-root ".bdt')\n")
	    (insert (ess-replace-in-string ess-bugs-temp-chains "##" "in"))
	    (insert "modelGenInits()\n")
	    (insert "modelUpdate(" (format "%d" (* bugs-thin bugs-burnin)) ")\n")
	    (insert ess-bugs-temp-monitor)
	    (insert "modelUpdate(" (format "%d" (* bugs-thin bugs-update)) ")\n")
;	    (insert (ess-replace-in-string
;		(ess-replace-in-string ess-bugs-temp-chains
;		    "modelCompile([0-9]+)" "#") "##" "to"))
	    (insert "samplesCoda('*', '" ess-bugs-file-root "')\n")

;	    (if ess-bugs-system (progn
;		(insert "system rm -f " ess-bugs-file-root ".ind\n")
;		(insert "system ln -s " ess-bugs-file-root "index.txt " ess-bugs-file-root ".ind\n")

;		(setq bugs-chains ess-bugs-chains)

;		(while (< 0 bugs-chains)
;		    (setq ess-bugs-temp-chain (format "%d" bugs-chains))

;		    ;.txt not recognized by BOA and impractical to over-ride
;		    (insert "system rm -f " ess-bugs-file-root ess-bugs-temp-chain ".out\n")
;		    (insert "system ln -s " ess-bugs-file-root "chain" ess-bugs-temp-chain ".txt "
;			ess-bugs-file-root ess-bugs-temp-chain ".out\n")
;		    (setq bugs-chains (- bugs-chains 1)))))

	    (insert "modelQuit()\n")
	    (insert "Local Variables" ":\n")
;	    (insert "enable-local-variables: :all\n")
	    (insert "ess-bugs-chains:" (format "%d" ess-bugs-chains) "\n")
	    (insert "ess-bugs-command:\"" ess-bugs-command "\"\n")
	    (insert "End:\n")
	))
    ))
)

(defun ess-bugs-na-bmd (bugs-command bugs-chains)
    "ESS[BUGS]: Perform the Next-Action for .bmd."
    ;(ess-save-and-set-local-variables)
(if (equal 0 (buffer-size)) (ess-bugs-switch-to-suffix ".bmd")
;else
    (shell)
    (ess-sleep)

    (if (and (w32-shell-dos-semantics) (string-equal ":" (substring ess-bugs-file 1 2)))
		(insert (substring ess-bugs-file 0 2)))

	(comint-send-input)
	(insert "cd \"" ess-bugs-file-dir "\"")
	(comint-send-input)

;    (let ((ess-bugs-temp-chains ""))
;
;	(while (< 0 bugs-chains)
;	    (setq ess-bugs-temp-chains
;		(concat (format "%d " bugs-chains) ess-bugs-temp-chains))
;	    (setq bugs-chains (- bugs-chains 1)))

	;; (insert "echo '"
	;; 	 ess-bugs-batch-pre-command " " bugs-command " < "
	;; 	 ess-bugs-file-root ".bmd > " ess-bugs-file-root ".bog 2>&1 "
	;; 	 ess-bugs-batch-post-command "' > " ess-bugs-file-root ".bsh")
	;; (comint-send-input)

	;; (insert "at -f " ess-bugs-file-root ".bsh now")

	;; (comint-send-input)

	(insert "echo '"
		 ess-bugs-batch-pre-command " " bugs-command " < "
		 ess-bugs-file-root ".bmd > " ess-bugs-file-root ".bog 2>&1 "
		 ess-bugs-batch-post-command "' | at now")

	(comint-send-input)
))

(defun ess-bugs-na-bug ()
    "ESS[BUGS]: Perform Next-Action for .bug"

	(if (equal 0 (buffer-size)) (ess-bugs-switch-to-suffix ".bug")
	;else
	    (ess-save-and-set-local-variables)
	    (ess-bugs-switch-to-suffix ".bmd"
		ess-bugs-chains ess-bugs-monitor ess-bugs-thin ess-bugs-burnin ess-bugs-update))
)

(defun ess-bugs-mode ()
   "ESS[BUGS]: Major mode for BUGS."
   (interactive)
   (kill-all-local-variables)
   (ess-setq-vars-local '((comment-start . "#")))
   (setq major-mode 'ess-bugs-mode)
   (setq mode-name "ESS[BUGS]")
   (use-local-map ess-bugs-mode-map)
   (setq font-lock-auto-fontify t)
   (make-local-variable 'font-lock-defaults)
   (setq font-lock-defaults '(ess-bugs-font-lock-keywords nil t))
   (run-hooks 'ess-bugs-mode-hook)

   (if (not (w32-shell-dos-semantics))
	(add-hook 'comint-output-filter-functions 'ess-bugs-exit-notify-sh))
)

(setq features (delete 'ess-bugs-d features))
(provide 'ess-bugs-d)
