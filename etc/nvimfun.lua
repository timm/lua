-- etc/nvimfun.lua : registers "fun" filetype + adds etc/ to runtimepath
-- so nvim auto-loads syntax/fun.vim. Sets buffer-local options.

local M = {}

function M.setup()
  vim.filetype.add({ extension = { fun = "fun" } })

  local dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
  vim.opt.runtimepath:prepend(dir)

  vim.api.nvim_create_autocmd("FileType", {
    group    = vim.api.nvim_create_augroup("nvimfun", { clear = true }),
    pattern  = "fun",
    callback = function(ev)
      local buf = ev.buf
      vim.bo[buf].commentstring = "-- %s"
      vim.bo[buf].expandtab     = true
      vim.bo[buf].shiftwidth    = 2
      vim.bo[buf].tabstop       = 2
    end,
  })
end

return M
