--- ~/.config/nvim/init.lua 
vim.g.mapleader = " "

-- Existing UI Options
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

-- Formatting Controls (Replacing the manual file headers)
vim.opt.expandtab      = true  -- 'et': Use spaces instead of tabs
vim.opt.shiftwidth     = 2     -- 'sw=2': 2 spaces per indentation level
vim.opt.tabstop        = 2     -- Match tabstop to shiftwidth
vim.opt.textwidth      = 90    -- 'tw=90': Hard wrap at 90 characters

-- Keymaps
local k = vim.keymap.set
k("i", "jk",        "<Esc>")
k("n", "<Esc>",     ":noh<CR>")
k("n", "<leader>w", ":w<CR>")
k("n", "<leader>q", ":q<CR>")
k("n", "<leader>e", ":Ex<CR>")

-- Lazy.nvim Bootstrap
local lp = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lp) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lp })
end
vim.opt.rtp:prepend(lp)

-- Plugin Setup
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
