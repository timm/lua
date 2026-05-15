#!/usr/bin/env bash
# etc/install.sh : install packages via brew/apt/dnf/pacman.
# usage: install.sh pkg1 pkg2 ...
# Some packages have per-manager names; mapped in map_pkg().
# Special bootstraps: pdflatex (TinyTeX), pycco (pip).
set -e

detect_mgr() {
  if   command -v brew    >/dev/null 2>&1; then echo brew
  elif command -v apt-get >/dev/null 2>&1; then echo apt
  elif command -v dnf     >/dev/null 2>&1; then echo dnf
  elif command -v pacman  >/dev/null 2>&1; then echo pacman
  else echo "no supported package manager found (brew/apt/dnf/pacman)" >&2; exit 1
  fi
}

# Map generic name -> manager-specific name. Empty result = skip (handled below).
map_pkg() {
  local g=$1
  case "$mgr:$g" in
    *:lua)            echo lua ;;
    apt:lua)          echo lua5.4 ;;
    brew:pygments)    echo pygments ;;
    apt:pygments)     echo python3-pygments ;;
    dnf:pygments)     echo python3-pygments ;;
    pacman:pygments)  echo python-pygments ;;
    *:pandoc)         echo pandoc ;;
    *:gawk)           echo gawk ;;
    *:a2ps)           echo a2ps ;;
    brew:ghostscript) echo ghostscript ;;
    apt:ghostscript)  echo ghostscript ;;
    dnf:ghostscript)  echo ghostscript ;;
    pacman:ghostscript) echo ghostscript ;;
    brew:luacheck)    echo luacheck ;;
    apt:luacheck)     echo lua-check ;;
    dnf:luacheck)     echo luacheck ;;
    pacman:luacheck)  echo luacheck ;;
    *:pdflatex)       echo "" ;;   # via TinyTeX
    *:pycco)          echo "" ;;   # via pip
    *:bat)            echo bat ;;
    *)                echo "$g" ;;
  esac
}

install_one() {
  local g=$1
  local pkg
  pkg=$(map_pkg "$g")

  # Special bootstraps.
  case "$g" in
    pdflatex)
      command -v pdflatex >/dev/null 2>&1 && return 0
      echo "installing TinyTeX..."
      curl -sL https://yihui.org/tinytex/install-bin-unix.sh | sh
      "$HOME/Library/TinyTeX/bin/"*/tlmgr install fancyvrb xcolor geometry multicol hyperref 2>/dev/null || true
      return 0 ;;
    pycco)
      command -v pycco >/dev/null 2>&1 && return 0
      echo "installing pycco via pip..."
      pip3 install --user pycco
      return 0 ;;
  esac

  [[ -z "$pkg" ]] && return 0

  echo "$mgr install $pkg ..."
  case "$mgr" in
    brew)   brew install "$pkg" 2>&1 | tail -3 || true ;;
    apt)    sudo apt-get install -y "$pkg" ;;
    dnf)    sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
  esac
}

mgr=$(detect_mgr)
echo "package manager: $mgr"
for p in "$@"; do install_one "$p"; done
echo "done."
