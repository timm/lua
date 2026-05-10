-- etc/nvimlet.lua : neovim filetype + syntax for the "let" language.
-- Loaded from etc/init.lua. Detects *.let files and applies highlighting.

local M = {}

function M.setup()
  -- Filetype detection.
  vim.filetype.add({ extension = { let = "let" } })

  -- Syntax / highlighting via autocmd (no separate ftplugin file required).
  local grp = vim.api.nvim_create_augroup("nvimlet", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group   = grp,
    pattern = "let",
    callback = function(ev)
      local buf = ev.buf

      -- Buffer-local options: 2-space indent, comment leader.
      vim.bo[buf].commentstring = "-- %s"
      vim.bo[buf].expandtab     = true
      vim.bo[buf].shiftwidth    = 2
      vim.bo[buf].tabstop       = 2

      -- Use Lua syntax as a base, then layer let-specific rules on top.
      vim.cmd[[runtime! syntax/lua.vim]]
      vim.cmd[[unlet! b:current_syntax]]

      -- let-specific keywords and operators.
      vim.cmd[[
        syntax keyword letKeyword       let Exports nextgroup=letName skipwhite
        syntax keyword letBlockKeyword  if elseif else for while do end return break
        syntax keyword letBoolean       true false nil
        syntax match   letReturnMark    /^\s*\^/
        syntax match   letBlockColon    /:$/
        syntax match   letBlockColon    /:\ze\s/
        syntax match   letPipe          /|>/
        syntax match   letCompound      /\v(\?|\+|-|\*|\/)\=/
        syntax match   letNotEq         /!=/
        syntax match   letPow           /\*\*/
        syntax match   letInterp        /{[^}]\+}/  containedin=luaString contained
        syntax match   letNumber        /\<\d\+\.\?\d*\>/

        highlight default link letKeyword       Keyword
        highlight default link letBlockKeyword  Statement
        highlight default link letBoolean       Boolean
        highlight default link letReturnMark    Special
        highlight default link letBlockColon    Operator
        highlight default link letPipe          Operator
        highlight default link letCompound      Operator
        highlight default link letNotEq         Operator
        highlight default link letPow           Operator
        highlight default link letInterp        Identifier
        highlight default link letNumber        Number
      ]]

      vim.b[buf].current_syntax = "let"
    end,
  })
end

return M
