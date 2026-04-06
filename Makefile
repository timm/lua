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
	@printf "$(CYAN)\n  Shoot for the moon. Even if you miss,\n"
	@printf "  you’ll land among the stars\n  — Les Brown\n\n$(RESET)"
	@I=$I bash --init-file $I/etc/bash.rc -i
 
OUT = ~/tmp/html
LUA = $(wildcard *.lua)
DOCS = $(LUA:%.lua=$(OUT)/%.html)

docs: $(OUT) $(DOCS)

$(OUT):
	@mkdir -p $(OUT)

$(OUT)/%.html: %.lua $I/etc/top.html
	@echo "Generating doco for $<"
	@pycco -d $(OUT) $<
	@cat $I/etc/my.css >> $(OUT)/pycco.css
	@gawk -v x="$$(cat $I/etc/top.html)" \
		'BEGIN {FS="<h1>"; RS="_jqz9v"} \
		       {print $$1 x $$2}' $@ > .$<
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
	@$(CSVS) 'lua ezr.lua --test {} 2>&1' | tee $@
	cut -d \  -f 1 $@ | sort -n | fmt -65

