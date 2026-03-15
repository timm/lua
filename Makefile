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

Font=5.5
Cols=3

~/tmp/%.pdf : %.py Makefile
	@echo "pdfing : $@ ... "
	@a2ps -Bj --landscape      \
		--line-numbers=1           \
		--font-size=$(Font) \
		--highlight-level=normal    \
		--columns=$(Cols)                  \
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

# B=50
#  2 13 17 21 22 31 32 35 40 41 42 44 44 48 48 49 49 53 53 53 54 54
# 54 55 55 55 56 57 58 58 58 59 59 60 61 62 63 63 64 64 65 66 66 68
# 70 71 74 74 75 75 76 77 77 77 77 78 78 78 79 80 80 80 80 80 81 81
# 82 83 84 84 84 86 86 86 86 87 87 88 88 89 89 89 89 90 90 91 91 91
# 92 92 93 93 93 93 93 94 94 94 94 95 95 96 96 96 96 96 97 97 97 97
# 97 97 98 98 98 98 98 98 98 99 100 100 100 100 100 100 100

# binarty using most lomhi
#  0  0  2  3  6  6 11 13 14 20 21 22 23 23 24 26 29 29 34 40 41 42 43 43
# 44 45 47 48 49 50 50 51 51 51 51 53 54 54 55 58 58 58 58 59 59 60
# 60 61 62 62 63 63 65 65 65 66 66 67 68 68 68 69 69 69 70 70 71 71
# 72 73 73 73 74 75 75 76 77 78 80 80 82 82 83 83 84 84 88 89 89 91
# 92 92 93 93 93 95 95 95 97 97 97 97 98 98 98 98 98 98 99 99 99 99
# 99 99 100 100 100 100 100 100 100 100 100 100 100 100 100

# binary splits using gaussian approximation
# -7 1 1 16 21 29 32 32 34 37 39 41 47 47 50 50 52 52 53 54 55 56
# 56 56 57 58 58 58 59 59 60 61 61 61 62 63 63 64 66 66 67 68 71 71
# 71 73 74 75 75 75 77 77 79 79 79 79 79 80 81 81 82 82 82 83 83 83
# 83 83 83 84 85 86 87 87 88 88 88 88 89 89 90 90 91 91 92 92 92 92
# 92 93 93 93 94 94 94 95 95 96 96 96 96 96 97 97 97 97 97 97 97 97
# 98 98 98 98 98 98 98 98 98 99 100 100 100 100 100 100 100


# 5 or 7 num splits minimized entropy
# 690762347317260140604176988110848 -7 4 7 10 24 35 35 38 38 39 40
# 43 44 48 48 49 51 52 52 53 54 55 56 56 56 57 58 58 60 61 61 61 62
# 62 63 63 63 63 64 64 65 68 69 70 71 72 73 73 74 75 75 75 76 76 76
# 76 76 77 77 77 80 81 81 81 81 82 82 83 83 84 85 86 86 87 87 87 88
# 88 88 89 89 89 90 90 90 91 92 92 92 93 93 93 94 94 94 95 95 95 95
# 95 96 96 96 96 96 97 97 97 97 98 98 98 98 98 98 98 98 98 98 100


~/tmp/lua_test.log:  ## run ezrtest on many files
	@mkdir -p ~/tmp
	@time ls -r $(HOME)/gits/moot/optimize/*/*.csv  | \
	   xargs -P 24 -n 1 -I{} sh -c 'python3 -B tree.py --test "{}"' | \
		 tee $@
	@sort -n $@  | cut -d, -f 1 | fmt -65

Html := ~/tmp

define AWK_SCRIPT
/^#[ \t]*[-—]+.*[-—]+/ { sub(/^#[ \t]*[-—]+[ \t]*/, ""); sub(/[ \t]*[-—]+.*$$/, ""); print "# ## " $$0 "\n\n"; next }
/^[ \t]*(def|class)/   { h=$$0; next }
h && /"""/             { gsub(/"""/,""); print "#"$$0; print h; h=""; next }
h                      { print h; h="" }
1
endef
export AWK_SCRIPT

define HEADER_HTML
<div class="custom-header" style="background:#f5f5f5; padding:10px 20px; border-bottom:1px solid #ccc; font-family:sans-serif; display: flex; justify-content: space-between; align-items: center;">
  
  <div>
    <strong>tree.py</strong> | 
    <span style="color:#666; font-size:0.9em;">Explainable Multi-Objective Optimization</span>
  </div>

  <div style="font-size: 0.9em;">
    <a href="https://github.com/timm/PROJECT" style="text-decoration:none; color:#0366d6;">GitHub</a> &bull; 
    <a href="https://github.com/timm/PROJECT/issues" style="text-decoration:none; color:#0366d6;">Issues</a>
  </div>

  <div style="display: flex; gap: 8px; align-items: center;">
    <img src="https://img.shields.io/badge/python-3.12+-blue.svg" alt="Python 3.12+" style="height: 20px; width: auto;">
    <img src="https://img.shields.io/badge/topic-Explainable%20AI-purple.svg" alt="Explainable AI" style="height: 20px; width: auto;">
    <a href="https://opensource.org/licenses/MIT" target="_blank" style="display: flex; align-items: center;">
      <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License: MIT" style="border:none; height: 20px; width: auto;">
    </a>
  </div>

</div>
endef
export HEADER_HTML

define CUSTOM_CSS
/* 1. Premium Typography Stack */
body, div.docs, p {
  /* Optima/Candara for Mac/Win (Humanist), then falling back to Verdana for readability */
  font-family: Optima, Candara, "Noto Sans", source-sans-pro, sans-serif !important;
  font-size: 15px;
  color: #333;
}

/* 2. Distinctive Header Font */
div.docs h1, div.docs h2, div.docs h3 {
  /* Trebuchet is slightly more "engineered" and works great for tech docs */
  font-family: "Trebuchet MS", "Lucida Grande", "Lucida Sans Unicode", "Lucida Sans", Tahoma, sans-serif !important;
  font-weight: bold;
  text-align: left !important;
  border-bottom: 1px solid #ddd;
  margin-top: 40px;
  display: block; 
  width: 100%;
}
div.docs h3 { border-bottom: 0px; }

/* 3. The "Hugging" Text */
div.docs, div.docs p {
  text-align: right !important;
  padding-right: 30px !important;
}

/* 4. Left-Anchored Code */
div.docs pre {
  font-family: "JetBrains Mono", "Fira Code", "Cascadia Code", "Courier New", monospace !important;
  text-align: left !important;
  display: block;
  margin: 15px 0 !important;
  font-size: 0.7em !important;
  background: #fbfbfb; /* Slightly warmer than pure white */
  padding: 12px;
  border: 1px solid #eee;
  border-left: 3px solid #7D9029; /* Subtle green accent to match your license badge */
}
endef
export CUSTOM_CSS

$(Html)/%.html: %.py
	@mkdir -p $(Html)
	@awk "$$AWK_SCRIPT" $< > $(Html)/$<
	@cd $(Html) && pycco -d . $<
	@echo "$$CUSTOM_CSS" >> $(Html)/pycco.css
	@awk '/<body/{print; print ENVIRON["HEADER_HTML"]; next} 1' $@ > $@.tmp && mv $@.tmp $@
	@rm $(Html)/$<

