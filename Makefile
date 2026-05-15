# vim: ts=2 sw=2 sts=2 et  :
I:= $(shell git rev-parse --show-toplevel)

help: ## show help.
	@gawk  '\
		BEGIN {FS = ":.*?##"; \
           printf "\nUsage:\n  make \033[36m<target>\033[0m [VAR=val ...]\n\ntargets:\n"} \
         /^[~a-z0-9A-Z_%\.\/-]+:.*?##/ { \
           printf("  \033[36m%-20s\033[0m %s\n", $$1, $$2) | "sort " } \
		'$(MAKEFILE_LIST)
	@printf '\n\033[1;33m.fun -> PDF (any path: make /dir/foo.pdf finds foo.fun):\033[0m\n'
	@printf '  Cols    number of cols   (default: $(Cols))\n'
	@printf '  Font    font size pts    (default: $(Font))\n'
	@printf '  Orient  landscape|portrait (default: $(Orient))\n'
	@printf '  Style   pygments style   (default: $(Style); see: pygmentize -L styles)\n'
	@printf '  LMargin left margin      (default: $(LMargin))\n'
	@printf '  RMargin right margin     (default: $(RMargin))\n'
	@printf '\n  example: make ~/tmp/ezr.pdf Cols=3 Font=5 Style=vs\n\n'

push: ## save to cloud
	@read -p "Reason? " msg; git commit -am "$$msg"; git push; git status

PKGS ?= lua pygments pandoc gawk a2ps ghostscript luacheck pdflatex pycco bat

install: ## install required tools (auto: brew/apt/dnf/pacman). vars: PKGS
	@bash etc/install.sh $(PKGS)

BLUE  := \033[34m
YELLOW := \033[1;33m
CYAN := \033[1;36m
RESET := \033[0m
CLS := \033[H\033[2J\033[3J

sh: ## start up my own IDE
	@printf "$(CLS)$(YELLOW)"
	@echo ' '
	@echo '  ⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠳⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
	@echo '  ⠀⠀⠀⠀⠀⠀⣀⡴⢧⣀⠀⠀⣀⣠⠤⠤⠤⠤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
	@echo '  ⠀⠀⠀⠀⠀⠀⠀⠘⠏⢀⡴⠊⠁⠀⠀⠀⠀⠀⠀⠈⠙⠦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
	@echo '  ⠀⠀⠀⠀⠀⠀⠀⠀⣰⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢶⣶⣒⣶⠦⣤⣀⠀⠀'
	@echo '  ⠀⠀⠀⠀⠀⠀⢀⣰⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣟⠲⡌⠙⢦⠈⢧⠀'
	@echo '  ⠀⠀⠀⣠⢴⡾⢟⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⡴⢃⡠⠋⣠⠋⠀'
	@echo '  ⠀⠐⠞⣱⠋⢰⠁⢿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⠤⢖⣋⡥⢖⣫⠔⠋⠀⠀⠀'
	@echo '  ⠈⠠⡀⠹⢤⣈⣙⠚⠶⠤⠤⠤⠴⠶⣒⣒⣚⣩⠭⢵⣒⣻⠭⢖⠏⠁⢀⣀⠀⠀⠀⠀'
	@echo '  ⠀⠠⠈⠓⠒⠦⠭⠭⠭⣭⠭⠭⠭⠭⠿⠓⠒⠛⠉⠉⠀⠀⣠⠏⠀⠀⠘⠞⠀⠀⠀⠀'
	@echo '  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠓⢤⣀⠀⠀⠀⠀⠀⠀⣀⡤⠞⠁⠀⣰⣆⠀⠀⠀⠀⠀⠀'
	@echo '  ⠀⠀⠀⠀⠀⠘⠿⠀⠀⠀⠀⠀⠈⠉⠙⠒⠒⠛⠉⠁⠀⠀⠀⠉⢳⡞⠉⠀⠀⠀⠀⠀'
	@echo '  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
	@printf "$(CYAN)\n'We choose to go to the moon... and do\n"
	@printf "the other things, not because they are easy,\n"
	@printf "but because they are hard.'  -- JFK\n\n$(RESET)"
	@I=$I bash --init-file $I/etc/bash.rc -i
 
HTML = ~/tmp/html
LUA = $(wildcard *.lua)
DOCS = $(LUA:%.lua=$(HTML)/%.html)

docs: $(HTML) $(DOCS)

$(HTML):; @mkdir -p $(HTML)

$(HTML)/%.html: %.lua $I/etc/top.html
	@echo "Generating doco for $<"
	@pycco -d $(HTML) $<
	@cat $I/etc/my.css >> $(HTML)/pycco.css
	@gawk -v x="$$(cat $I/etc/top.html)" \
    'BEGIN {FS="<h1>"; RS="^$$"} {print $$1 x "<h1>" $$2}' $@ > .$<
	@mv .$< $@

Font ?=5
Cols ?=3

Orient  ?= landscape
Style   ?= friendly
LMargin ?= 1.5cm
RMargin ?= 0.5cm

.SECONDEXPANSION:
%.pdf : $$(notdir $$*).fun Makefile etc/funpdf.sh
	@bash etc/funpdf.sh "$<" "$@" "$(Cols)" "$(Font)" "$(Orient)" "$(Style)" "$(LMargin)" "$(RMargin)"
	@open $@

docs/%.html : docs/%.md ## render markdown -> standalone html
	pandoc -s -f markdown -t html $< -o $@

docs/%.tex : docs/%.md ## render markdown -> latex (uses fun listings)
	@{ printf '\\documentclass[10pt,twocolumn]{article}\n'; \
	   printf '\\usepackage[utf8]{inputenc}\n'; \
	   printf '\\usepackage[T1]{fontenc}\n'; \
	   printf '\\usepackage{listings}\n'; \
	   printf '\\usepackage{xcolor}\n'; \
	   printf '\\usepackage[margin=1cm]{geometry}\n'; \
	   printf '\\usepackage{longtable,booktabs,array}\n'; \
	   printf '\\newcounter{none}\n'; \
	   printf '\\providecommand{\\passthrough}[1]{#1}\n'; \
	   printf '\\providecommand{\\tightlist}{\\setlength{\\itemsep}{0pt}\\setlength{\\parskip}{0pt}}\n'; \
	   printf '\\input{fun}\n\n'; \
	   printf '\\begin{document}\n\n'; \
	   pandoc --listings -f markdown -t latex $< 2>/dev/null \
	     | sed -e 's/language=fun/language=Fun/g' \
	           -e 's/^\\begin{lstlisting}$$/\\begin{lstlisting}[language=Fun]/'; \
	   printf '\n\\end{document}\n'; \
	 } > $@
	@echo "wrote $@ (companion: etc/fun-listings.tex -> upload as fun.tex)"

~/tmp/%.pdf : %.lua Makefile $I/etc/lua.ssh
	@echo "pdfing : $@ ... "
	@a2ps -Bj --landscape --line-numbers=1 --highlight-level=normal \
		--borders=no --pro=color --right-footer="" --left-footer=""  \
		--pretty-print=$I/etc/lua.ssh --footer="page %p." -M letter \
		--font-size=$(Font) --columns $(Cols) \
		-o - $< | ps2pdf - $@
	open $@

F ?= at.lua
check: ## luacheck a .lua file (var: F)
	luacheck --config $I/etc/check.rc $F

# Pretty-print one paragraph of a .fun file to PDF.
# usage: make snip S=keyword [SRC=file.fun]
S    ?=
SRC  ?= ezr.fun
SDIR ?= /tmp/snip

snip: ## render first para of $(SRC) matching S to PDF
	@test -n "$(S)" || \
	  (echo "usage: make snip S=keyword [SRC=file.fun]"; exit 1)
	@mkdir -p $(SDIR)
	@gawk -v pat="$(S)" 'BEGIN{RS="";ORS="\n\n"} \
	   $$0 ~ pat {print; exit}' $(SRC) > $(SDIR)/snip.fun
	@test -s $(SDIR)/snip.fun || \
	  (echo "no paragraph matched: $(S)"; exit 1)
	@pygmentize -x -l etc/funlexer.py:FunLexer \
	  -f latex -O full,style=tango \
	  -o $(SDIR)/snip.tex $(SDIR)/snip.fun
	@cd $(SDIR) && pdflatex -interaction=batchmode snip.tex >/dev/null
	@open $(SDIR)/snip.pdf

snip-tex: ## emit pygmentized LaTeX body to stdout (for | pbcopy)
	@test -n "$(S)" || \
	  (echo "usage: make snip-tex S=keyword" >&2; exit 1)
	@gawk -v pat="$(S)" 'BEGIN{RS="";ORS="\n\n"} \
	   $$0 ~ pat {print; exit}' $(SRC) \
	 | pygmentize -x -l etc/funlexer.py:FunLexer \
	     -f latex -O style=tango

snip-listings: ## emit para wrapped in \begin{lstlisting}[language=Fun] (for | pbcopy)
	@test -n "$(S)" || \
	  (echo "usage: make snip-listings S=keyword" >&2; exit 1)
	@printf '\\begin{lstlisting}[language=Fun]\n'
	@gawk -v pat="$(S)" 'BEGIN{RS="";ORS="\n\n"} \
	   $$0 ~ pat {print; exit}' $(SRC)
	@printf '\\end{lstlisting}\n'

snip-raw: ## emit raw .fun para to stdout (for | pbcopy)
	@test -n "$(S)" || \
	  (echo "usage: make snip-raw S=keyword" >&2; exit 1)
	@gawk -v pat="$(S)" 'BEGIN{RS="";ORS="\n\n"} \
	   $$0 ~ pat {print; exit}' $(SRC)
