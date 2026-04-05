# vim: ts=2 sw=2 sts=2 et  :
I:= $(shell git rev-parse --show-toplevel)

help: ## show help.
	@gawk  '\
		BEGIN {FS = ":.*?##"; \
           printf "\nUsage:\n  make \033[36m<target>\033[0m\n\ntargets:\n"} \
         /^[~a-z0-9A-Z_%\.\/-]+:.*?##/ { \
           printf("  \033[36m%-15s\033[0m %s\n", $$1, $$2) | "sort " } \
		'$(MAKEFILE_LIST)

push: ## save to cloud
	@read -p "Reason? " msg; git commit -am "$$msg"; git push; git status

BLUE  := \033[34m
RESET := \033[0m

sh: ## start up my own IDE
	@reset
	@printf "$(BLUE)%b$(RESET)\n" "$$(figlet -W -f larry3D lua)"
	@I=$I bash --init-file $I/etc/bash.rc -i

~/tmp/%.html: %.lua $I/etc/top.html ## lua to pdf
	@pycco -d $(dir $@) $<
	@echo 'p {text-align: right}' >> $(dir $@)pycco.css
	@gawk -v x="$$(cat $I/etc/top.html)" \
    'BEGIN {FS="<h1>"; RS="_jqz9v"} \
           {print $$1 x "<h1>" $$2}' $@ > .$<
	@mv .$< $@

Font ?=5
Cols ?=3

~/tmp/%.pdf : %.lua Makefile $I/etc/lua.ssh
	@echo "pdfing : $@ ... "
	@a2ps -Bj --landscape --line-numbers=1 --highlight-level=normal \
		--borders=no --pro=color --right-footer="" --left-footer=""  \
		--pretty-print=$I/etc/lua.ssh --footer="page %p." -M letter \
		--font-size=$(Font) --columns $(Cols) \
		-o - $< | ps2pdf - $@
	open $@

F?=tree.lua
check:
	luacheck --config $I/etc/check.rc $F

CSVS=ls -r ~/gits/moot/optimize/*/*.csv | xargs -P 20 -I {} sh -c 

~/tmp/luatest.log :
	@$(CSVS) 'lua tree.lua  --test {} 2>&1' | tee $@
	cut -d \  -f 1 $@ | sort -n | fmt -65

