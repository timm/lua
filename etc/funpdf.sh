#!/usr/bin/env bash
# etc/funpdf.sh : .fun -> PDF via pygmentize + pandoc + pdflatex.
# At column 0:
#   `-- # X`   -> title    (largest)
#   `-- ## X`  -> section
#   `-- ### X` -> subsection
#   `-- ...`   -> markdown prose (bold/italic/code/lists/links)
# Everything else -> code (pygmentized .fun).
# Indented `--` comments stay inside code chunks.
# usage: atpdf.sh SRC OUT [COLS=2] [FONT=9] [ORIENT=landscape] [STYLE=tango]
set -e
src=$1
out=$2
cols=${3:-2}
font=${4:-9}
orient=${5:-landscape}
style=${6:-tango}
lmargin=${7:-1.5cm}
rmargin=${8:-0.5cm}

[[ -n "$src" && -n "$out" ]] || {
  echo "usage: atpdf.sh SRC OUT [COLS] [FONT] [ORIENT] [STYLE] [LMARGIN] [RMARGIN]" >&2; exit 1
}
[[ -f "$src" ]] || { echo "no such file: $src" >&2; exit 1; }

here=$(CDPATH= cd -- "$(dirname -- "$0")" >/dev/null && pwd -P)
tmp=$(mktemp -d)
trap "rm -rf $tmp" EXIT

# Heading sizes derived from body font.
h1=$(awk "BEGIN{printf \"%.2f\", $font*2.0}")
h1l=$(awk "BEGIN{printf \"%.2f\", $font*2.2}")
h2=$(awk "BEGIN{printf \"%.2f\", $font*1.5}")
h2l=$(awk "BEGIN{printf \"%.2f\", $font*1.7}")
h3=$(awk "BEGIN{printf \"%.2f\", $font*1.2}")
h3l=$(awk "BEGIN{printf \"%.2f\", $font*1.4}")
ln=$(awk "BEGIN{printf \"%.2f\", $font*0.75}")
lnl=$(awk "BEGIN{printf \"%.2f\", $font*0.9}")

# Pygments macro preamble — cached per style under etc/.
prefile="$here/pygments-$style.tex"
if [[ ! -f "$prefile" ]]; then
  pygmentize -x -l "$here/funlexer.py:FunLexer" -f latex \
    -O full,style=$style /dev/null \
   | sed -n '/^\\makeatletter/,/^\\makeatother/p' > "$prefile"
fi

# Split source into chunks. Manifest fields:
#   H <latex>           -> emit literal heading line
#   P <file>            -> pandoc markdown -> latex
#   C <file> <linestart> -> pygmentize as code
manifest="$tmp/manifest.tsv"
: > "$manifest"
gawk -v outdir="$tmp" -v manifest="$manifest" '
  function flush(   f) {
    if (buf == "") return
    n++
    if (kind == "P") {
      f = sprintf("%s/p_%04d.md", outdir, n)
      printf "%s", buf > f; close(f)
      printf "P\t%s\n", f >> manifest
    } else {
      f = sprintf("%s/c_%04d.fun", outdir, n)
      printf "%s", buf > f; close(f)
      printf "C\t%s\t%d\n", f, first >> manifest
    }
    buf = ""; kind = ""
  }
  /^$/ {
    if (kind != "") buf = buf "\n"
    next
  }
  /^-- ### / {
    flush(); t = $0; sub(/^-- ### /, "", t)
    printf "H\t\\atSubsec{%s}\n", t >> manifest; next
  }
  /^-- ## / {
    flush(); t = $0; sub(/^-- ## /, "", t)
    sec_n++
    if (sec_n > 1)
      printf "H\t\\columnbreak\\atSection{%s}\n", t >> manifest
    else
      printf "H\t\\atSection{%s}\n", t >> manifest
    next
  }
  /^-- # / {
    flush(); t = $0; sub(/^-- # /, "", t)
    printf "H\t\\atTitle{%s}\n", t >> manifest; next
  }
  /^-- / || /^--$/ {
    if (kind == "C") flush()
    kind = "P"
    line = $0
    sub(/^-- ?/, "", line)
    buf = buf line "\n"
    next
  }
  {
    if (kind == "P") flush()
    if (kind == "") { kind = "C"; first = NR }
    buf = buf $0 "\n"
  }
  END { flush() }
' "$src"

# Render each chunk to body.tex.
body="$tmp/body.tex"
: > "$body"
while IFS=$'\t' read -r kind a b; do
  case "$kind" in
    H) printf '%s\n' "$a" >> "$body" ;;
    P) pandoc -f markdown -t latex "$a" | awk 'NF{p=1} p' | sed -e :a -e '/^$/{$d;N;ba' -e '}' >> "$body" ;;
    C) pygmentize -x -l "$here/funlexer.py:FunLexer" -f latex \
         -O "linenos=True,linenostart=$b,style=$style,verboptions=numbersep=8pt" "$a" >> "$body"
       echo >> "$body" ;;
  esac
done < "$manifest"

cat > "$tmp/main.tex" <<EOF
\documentclass[10pt]{article}
\usepackage[$orient,left=$lmargin,right=$rmargin,top=1cm,bottom=1cm,includefoot,footskip=12pt]{geometry}
\usepackage{multicol}
\usepackage{fancyvrb}
\usepackage{xcolor}
\usepackage{hyperref}
\AtBeginDocument{\fontsize{$font}{$font}\selectfont}
\renewcommand{\theFancyVerbLine}{\sffamily\textcolor{gray!60}{\fontsize{$ln}{$lnl}\selectfont\arabic{FancyVerbLine}}}
\newcommand{\atTitle}[1]{\par\bigskip\noindent{\fontsize{$h1}{$h1l}\selectfont\bfseries #1}\par\nobreak}
\newcommand{\atSection}[1]{\par\medskip\noindent{\fontsize{$h2}{$h2l}\selectfont\bfseries #1}\par\nobreak}
\newcommand{\atSubsec}[1]{\par\smallskip\noindent{\fontsize{$h3}{$h3l}\selectfont\bfseries\itshape #1}\par\nobreak}
% Kill vertical padding before Verbatim.
\setlength{\topsep}{0pt}
\setlength{\partopsep}{0pt}
\setlength{\parskip}{0pt}
% pandoc emits \tightlist; provide noop if not present
\providecommand{\tightlist}{\setlength{\itemsep}{0pt}\setlength{\parskip}{0pt}}
% page M of N (no fancyhdr/lastpage needed)
\makeatletter
\newcommand{\@putlastpagelabel}{%
  \immediate\write\@auxout{\string\newlabel{LastPage}{{}{\the\c@page}{}{}{}}}}
\AtEndDocument{\@putlastpagelabel\clearpage}
\def\@oddfoot{\hfil page \thepage\ of \pageref{LastPage}\hfil}
\def\@evenfoot{\hfil page \thepage\ of \pageref{LastPage}\hfil}
\makeatother
EOF
cat "$prefile" >> "$tmp/main.tex"
cat >> "$tmp/main.tex" <<EOF
\setlength{\parindent}{0pt}
\begin{document}
\raggedcolumns
\begin{multicols}{$cols}
EOF
cat "$body" >> "$tmp/main.tex"
cat >> "$tmp/main.tex" <<EOF
\end{multicols}
\end{document}
EOF

cd "$tmp"
pdflatex -interaction=batchmode main.tex >/dev/null || true
pdflatex -interaction=batchmode main.tex >/dev/null
mkdir -p "$(dirname "$out")"
mv main.pdf "$out"
echo "wrote $out"
