-- etc/nvimlet.lua : neovim filetype + syntax + abbrevs for the "let" language.
-- Loaded from etc/init.lua. Detects *.let files and applies highlighting.
-- Reuses Lua syntax then layers let-specific tokens on top.

local M = {}

function M.setup()
  vim.filetype.add({ extension = { let = "let" } })

  local grp = vim.api.nvim_create_augroup("nvimlet", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group   = grp,
    pattern = "let",
    callback = function(ev)
      local buf = ev.buf

      vim.bo[buf].commentstring = "-- %s"
      vim.bo[buf].expandtab     = true
      vim.bo[buf].shiftwidth    = 2
      vim.bo[buf].tabstop       = 2

      -- Base on Lua syntax then overlay let tokens.
      vim.cmd[[runtime! syntax/lua.vim]]
      vim.cmd[[unlet! b:current_syntax]]

      vim.cmd[[
        " let-specific keywords
        syntax keyword letKeyword       let Exports
        " return marker
        syntax match   letReturn        /\^/
        syntax match   letReturn        /↑/
        " block delimiters (mini variant)
        syntax match   letOpen          /›/
        syntax match   letClose         /‹/
        " function symbol
        syntax match   letLambda        /λ/
        " pipe
        syntax match   letPipe          /|>/
        syntax match   letPipe          /▶/
        " operators
        syntax match   letCompound      /\v(\?|\+|-|\*|\/)\=/
        syntax match   letNotEq         /!=/
        syntax match   letPow           /\*\*/
        " block-opener colon (full variant)
        syntax match   letBlockColon    /:$/
        syntax match   letBlockColon    /:\ze\s/
        " interpolation inside strings
        syntax match   letInterp        /{[^}]\+}/ containedin=luaString contained

        highlight default link letKeyword    Keyword
        highlight default link letReturn     Special
        highlight default link letOpen       Statement
        highlight default link letClose      Statement
        highlight default link letLambda     Keyword
        highlight default link letPipe       Operator
        highlight default link letCompound   Operator
        highlight default link letNotEq      Operator
        highlight default link letPow        Operator
        highlight default link letBlockColon Operator
        highlight default link letInterp     Identifier
      ]]

      -- Buffer-local abbreviations.
      vim.cmd[[
        iabbrev <buffer> \l λ
        iabbrev <buffer> \r ↑
        iabbrev <buffer> \\| ▶
        " math-style alternates
        iabbrev <buffer> \ne ≠
        iabbrev <buffer> \le ≤
        iabbrev <buffer> \ge ≥
      ]]

      vim.b[buf].current_syntax = "let"
    end,
  })
end

return M
