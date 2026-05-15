" syntax/fun.vim : syntax for the "fun" language.
" Reuses Lua syntax then overlays fun-specific tokens.
if exists("b:current_syntax") | finish | endif

runtime! syntax/lua.vim
unlet! b:current_syntax

" Lua's luaError flags bare end/else/elseif/then/until/in.
" Clear it; we re-add an orphan-end check below after our regions.
syntax clear luaError

" `fun ... end` block (mirrors lua's luaFunctionBlock).
syntax region funFunBlock transparent matchgroup=funKeyword
  \ start=/\<fun\>/ end=/\<end\>/ contains=TOP

" `if (cond) ... end` block. Source omits `then`, so lua's
" luaCondStart never fires. Define our own.
syntax region funIfBlock transparent matchgroup=funKeyword
  \ start=/\<if\>\ze\s*(/ end=/\<end\>/ contains=TOP

syntax keyword funKeyword  let else elseif
syntax match   funReturn   /!/
syntax match   funConcat   /++/
syntax match   funCondInit /?=/
syntax match   funCompound /\v(\+|-|\*|\/)\=/

" Any `end` not consumed by a region is orphan.
syntax match   funOrphanEnd /\<end\>/

highlight default link funKeyword  Keyword
highlight default link funReturn   Special
highlight default link funConcat   Operator
highlight default link funCondInit Operator
highlight default link funCompound Operator
highlight default link funOrphanEnd Error

let b:current_syntax = "fun"
