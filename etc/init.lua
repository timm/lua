--- ~/.config/nvim/init.lua  (:Lazy sync on first load)
vim.g.mapleader = " "

vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.cursorline     = true
vim.opt.termguicolors  = true
vim.opt.ignorecase     = true
vim.opt.smartcase      = true
vim.opt.clipboard      = "unnamedplus"
vim.opt.undofile       = true
vim.opt.scrolloff      = 8
vim.opt.updatetime     = 200

local k = vim.keymap.set
k("i", "jk",        "<Esc>")
k("n", "<Esc>",     ":noh<CR>")
k("n", "<leader>w", ":w<CR>")
k("n", "<leader>q", ":q<CR>")
k("n", "<leader>e", ":Ex<CR>")

local lp = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lp) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lp })
end
vim.opt.rtp:prepend(lp)

require("lazy").setup({

  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    config = function()
      local ok, ts = pcall(require, "nvim-treesitter.configs")
      if not ok then return end
      ts.setup({
        ensure_installed = { "lua", "python", "bash" },
        highlight = { enable = true },
      })
    end
  },

  { "rebelot/kanagawa.nvim", lazy = false, priority = 1000,
    config = function() vim.cmd("colorscheme kanagawa") end },
})
