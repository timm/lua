" syntax/bang.vim : syntax for the "bang" language.
" Reuses Lua syntax then overlays bang-specific tokens.
if exists("b:current_syntax") | finish | endif

runtime! syntax/lua.vim
unlet! b:current_syntax

syntax keyword bangKeyword  let
syntax match   bangLambda   /λ/
syntax match   bangReturn   /\^/
syntax match   bangEnd      /!/
syntax match   bangCompound /\v(\?|\+|-|\*|\/)\=/
syntax match   bangPow      /\*\*/
syntax match   bangConcat   /++/

highlight default link bangKeyword  Keyword
highlight default link bangLambda   Keyword
highlight default link bangReturn   Special
highlight default link bangEnd      Special
highlight default link bangCompound Operator
highlight default link bangPow      Operator
highlight default link bangConcat   Operator

let b:current_syntax = "bang"
