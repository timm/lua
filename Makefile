# vim: ts=2 sw=2 noet
# Copyright (c) 2025 Tim Menzies, MIT License
# https://opensource.org/licenses/MIT
#------------------------------------------------------
SHELL=/bin/bash
.SILENT:
.PHONY: help egs ok eg-nbc eg-abcd eg-soybean eg-globals pull push

help: ## show this help
	@gawk 'BEGIN { FS=":.*?## ";c="\033[1;3"; r="\033[0m";            \
		             printf "\n%s6mmake%s [%s3moptions%s]:\n\n",c,r,c,r} \
         NF==2 && $$1~/^[a-z0-9A-Z_-]+/{                              \
				         printf "  %s2m%-15s%s %s\n",c,$$1,r,$$2}' $(MAKEFILE_LIST)

# misc ------------------------------------------------
sh: ## run a customized shell
	sh ell

push: ## commit to main
	echo -en "Why this push? " 
	read x ; git commit -am "$$x" ;  git push ; git status

pull: ## commit to main
	git pull

Lines=90
Cols=2

~/tmp/%.pdf : %.lua Makefile lua.ssh
	@echo "pdfing : $@ ... "
	@a2ps -Bj --landscape      \
		--line-numbers=1           \
	  --chars-per-line=$(Lines) \
		--highlight-level=normal    \
		--columns $(Cols)                  \
		--borders=no --pro=color      \
		--right-footer="" --left-footer=""  \
		--pretty-print=lua.ssh               \
		--footer="page %p."                   \
		-M letter                              \
		-o - $< | ps2pdf - $@
	open $@

~/tmp/%.pdf : %.jl Makefile julia.ssh
	@echo "pdfing : $@ ... "
	@a2ps -Bj --landscape      \
		--line-numbers=1           \
	  --chars-per-line=$(Lines) \
		--highlight-level=normal    \
		--columns $(Cols)                  \
		--borders=no --pro=color      \
		--right-footer="" --left-footer=""  \
		--pretty-print=julia.ssh               \
		--footer="page %p."                   \
		-M letter                              \
		-o - $< | ps2pdf - $@
	open $@

