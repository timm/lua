# vim: ts=2 sw=2 noet
# Copyright (c) 2025 Tim Menzies, MIT License
# vim: ts=2 sw=2 noet
# Copyright (c) 2025 Tim Menzies, MIT License
# https://opensource.org/licenses/MIT
#------------------------------------------------------
SHELL=/bin/bash
.SILENT:
.PHONY: help egs ok eg-nbc eg-abcd eg-soybean eg-globals pull push

help: ## show this help
	@gawk 'BEGIN { FS=":.*?## ";c="\033[1;3"; r="\033[0m"; \
	  printf "\n%s6mmake%s [%s3moptions%s]:\n\n",c,r,c,r} \
	  NF==2 && $$1~/^[a-z0-9A-Z_-]+/{ \
	  printf "  %s2m%-15s%s %s\n",c,$$1,r,$$2}' $(MAKEFILE_LIST)

# misc ------------------------------------------------
sh: ## run a customized shell
	sh ell

push: ## commit to main
	echo -en "Why this push? " 
	read x ; git commit -am "$$x" ; git push ; git status

pull: ## commit to main
	git pull

Font=5
Cols=3
Html := ~/tmp

~/tmp/%.pdf : %.py Makefile
	@echo "pdfing : $@ ... "
	@a2ps -Bj --landscape --line-numbers=1 --font-size=$(Font) \
	  --highlight-level=normal --columns=$(Cols) --borders=no --pro=color \
	  --right-footer="" --left-footer="" --footer="page %p." -M letter \
	  -o - $< | ps2pdf - $@
	open $@

~/tmp/%.pdf : %.lua Makefile lua.ssh
	@echo "pdfing : $@ ... "
	@a2ps -Bj --landscape --line-numbers=1 --chars-per-line=$(Lines) \
	  --highlight-level=normal --columns $(Cols) --borders=no --pro=color \
	  --right-footer="" --left-footer="" --pretty-print=lua.ssh \
	  --footer="page %p." -M letter -o - $< | ps2pdf - $@
	open $@

~/tmp/%.pdf : %.jl Makefile julia.ssh
	@echo "pdfing : $@ ... "
	@a2ps -Bj --landscape --line-numbers=1 --chars-per-line=$(Lines) \
	  --highlight-level=normal --columns $(Cols) --borders=no --pro=color \
	  --right-footer="" --left-footer="" --pretty-print=julia.ssh \
	  --footer="page %p." -M letter -o - $< | ps2pdf - $@
	open $@

~/tmp/lua_test.log:  ## run ezrtest on many files
	@mkdir -p ~/tmp
	time ls -r $(HOME)/gits/moot/optimize/*/*.csv | \
	  xargs -P 24 -n 1 -I{} sh -c 'python3 -B ez.py --test "{}"' | \
	  tee $@
	@sort -n $@ | cut -d, -f 1 | fmt -80

~/tmp/ezr_cluster.log:  ## run ezrtest on many files
	@mkdir -p ~/tmp
	time ls -r $(HOME)/gits/moot/optimize/config/SS* | \
	  xargs -P 24 -n 1 -I{} sh -c 'python3 -B ezr.py --cluster "{}"' | \
	  tee $@
	@sort -n $@ | cut -d, -f 1 | fmt -80

~/tmp/ezr_test.log:  ## run ezrtest on many files
	@mkdir -p ~/tmp
	time ls -r $(HOME)/gits/moot/optimize/*/*.csv | \
	  xargs -P 24 -n 1 -I{} sh -c 'python3 -B ezr.py -test "{}"' | \
	  tee $@
	@sort -n $@ | cut -d, -f 1 | fmt -65

# Pre-processor for Python -> Markdown headers
define AWK_PY
/^#[ \t]*[-—]{4}/ {
  sub(/^#[ \t]*[-—]+[ \t]*/, ""); sub(/[ \t]*[-—]+.*$$/, "");
  print "# ## " $$0 "\n\n"; next
}
/^#[ \t]*[-—]{3}/ {
  sub(/^#[ \t]*[-—]+[ \t]*/, ""); sub(/[ \t]*[-—]+.*$$/, "");
  print "# ### " $$0 "\n\n"; next
}
/^#[ \t]*[-—]{2}/ {
  sub(/^#[ \t]*[-—]+[ \t]*/, ""); sub(/[ \t]*[-—]+.*$$/, "");
  print "# #### " $$0 "\n\n"; next
}
/^[ \t]*(def|class)/ { h=$$0; next }
h && /"""/           { gsub(/"""/,""); print "#"$$0; print h; h=""; next }
h                    { print h; h="" }
1
endef
export AWK_PY

# Post-processor for Pycco HTML
define AWK_HTML
BEGIN { s=0 }
/<body/ {
  print; print ENVIRON["HEADER_HTML"]; next
}
/<h2>/ { s=1 }
/class=.section/ {
  if(!s) sub(/class=\047section\047/, "class=\047section intro\047")
}
1
endef
export AWK_HTML

define HEADER_HTML
<link rel="stylesheet"
  href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<div class="custom-header" style="background:#f8f9fa; padding:12px 30px;
  border-bottom:1px solid #ddd; font-family:Optima, Candara, sans-serif;
  display: flex; justify-content: space-between; align-items: center;
  overflow-x: auto; white-space: nowrap;">
  <div style="font-size: 1.05em; font-weight: 500; display: flex; gap: 20px;
    flex-shrink: 0; white-space: nowrap;">
    <a href="https://github.com/timm/PROJECT" target="_blank"
      style="text-decoration:none; color:#0366d6; display: flex;
      align-items: center; gap: 5px;">
      <i class="fa-brands fa-github"></i> GitHub
      <i class="fa-solid fa-arrow-up-right-from-square"
        style="font-size:0.7em;"></i>
    </a>
    <a href="https://github.com/timm/PROJECT/issues" target="_blank"
      style="text-decoration:none; color:#0366d6; display: flex;
      align-items: center; gap: 5px;">
      <i class="fa-solid fa-circle-exclamation"></i> Issues
      <i class="fa-solid fa-arrow-up-right-from-square"
        style="font-size:0.7em;"></i>
    </a>
  </div>
  <div style="display: flex; gap: 10px; align-items: center; flex-shrink: 0;
    margin-left: 20px;">
    <img style="height:22px;" alt="Python"
      src="https://img.shields.io/badge/python-3.12+-3776ab.svg?style=flat-square&logo=python&logoColor=white">
    <img style="height:22px;" alt="XAI"
      src="https://img.shields.io/badge/topic-XAI-purple.svg?style=flat-square">
    <a href="https://opensource.org/licenses/MIT" target="_blank"
      style="display:flex; align-items:center;">
      <img style="height:22px; border:none;" alt="MIT"
        src="https://img.shields.io/badge/license-MIT-green.svg?style=flat-square">
    </a>
  </div>
</div>
endef
export HEADER_HTML

define CUSTOM_CSS
/* 1. Fonts and Basic Styling */
body, div.docs, p { 
  font-family: Optima, Candara, "Noto Sans", sans-serif !important; 
  font-size: 15px; color: #333; 
}
pre, code, .code { font-family: "JetBrains Mono", "Fira Code", monospace; }

/* 2. GAP KILLER: Remove Pycco's default top padding/margins */
#container { margin-top: 0 !important; }
div.docs, div.code { padding-top: 10px !important; }

/* 3. The "Hugging" Text */
div.docs, div.docs p {
  text-align: right !important; padding-right: 35px !important;
}

/* 4. Left-Anchored Headers */
div.docs h1, div.docs h2, div.docs h3 { 
  text-align: left !important; border-bottom: 1px solid #eee; 
  width: 100%; display: block; margin-top: 40px; 
}

/* 5. Special case: First H1 should have almost no top margin */
div.docs h1:first-child, div.section:first-child h1 { 
  margin-top: 5px !important; 
}
div.docs h3 { border-bottom: none; color: #555; }

/* 6. LHS Code Blocks */
div.docs pre {
  text-align: left !important; margin: 20px 0 !important;
  font-size: 0.75em !important; background: #fdfdfd; padding: 15px;
  border: 1px solid #eee; border-left: 4px solid #7D9029;
}
div.section.intro div.docs, div.section.intro div.docs p {
  text-align: left !important;
}
endef
export CUSTOM_CSS

docs: ~/tmp/ezr.html ~/tmp/ezr.pdf

$(Html)/%.html: %.py
	@mkdir -p $(Html)
	@awk "$$AWK_PY" $< > $(Html)/$<
	@cd $(Html) && pycco -d . $<
	@echo "$$CUSTOM_CSS" >> $(Html)/pycco.css
	@awk "$$AWK_HTML" $@ > $@.tmp && mv $@.tmp $@
	@rm $(Html)/$<

