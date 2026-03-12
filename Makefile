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

~/tmp/%.pdf : %.py Makefile
	@echo "pdfing : $@ ... "
	@a2ps -Bj --portrait      \
		--line-numbers=1           \
	  --chars-per-line=$(Lines) \
		--highlight-level=normal    \
		--columns $(Cols)                  \
		--borders=no --pro=color      \
		--right-footer="" --left-footer=""  \
		--footer="page %p."                   \
		-M letter                              \
		-o - $< | ps2pdf - $@
	open $@

~/mp/%.pdf : %.lua Makefile lua.ssh
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

#0 0 2 3 6 6 11 13 14 20 21 22 23 23 24 26 29 29 34 40 41 42 43 43
#44 45 47 48 49 50 50 51 51 51 51 53 54 54 55 58 58 58 58 59 59 60
#60 61 62 62 63 63 65 65 65 66 66 67 68 68 68 69 69 69 70 70 71 71
#72 73 73 73 74 75 75 76 77 78 80 80 82 82 83 83 84 84 88 89 89 91
#92 92 93 93 93 95 95 95 97 97 97 97 98 98 98 98 98 98 99 99 99 99
#99 99 100 100 100 100 100 100 100 100 100 100 100 100 100

~/tmp/lua_test.log:  ## run ezrtest on many files
	@mkdir -p ~/tmp
	@time ls -r $(HOME)/gits/moot/optimize/*/*.csv  | \
	   xargs -P 24 -n 1 -I{} sh -c 'python3 -B tree.py  --seed $$RANDOM --test "{}"' | \
		 tee $@
	@sort -n $@  | cut -d, -f 1 | fmt -65

~/tmp/lua_testnp.log:  ## run ezrtest on many files
	@mkdir -p ~/tmp
	@time ls -r $(HOME)/gits/moot/optimize/*/*.csv  | \
	   xargs -P 24 -n 1 -I{} sh -c 'python3 -B treenp.py  --seed $$RANDOM --test "{}"' | \
		 tee $@
	@sort -n $@  | cut -d, -f 1 | fmt -65


