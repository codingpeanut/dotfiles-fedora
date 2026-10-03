-- Neovim configuration (init.lua)
-- Managed by dotfiles (GNU Stow)

local opt = vim.opt
local g = vim.g

-- Leader key
g.mapleader = " "
g.maplocalleader = " "

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & Indentation
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- Search settings
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Visuals & Theme
opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.scrolloff = 8
opt.wrap = false

-- Wayland / System Clipboard Integration
opt.clipboard = "unnamedplus"

-- Keybindings
local keymap = vim.keymap.set

-- Clear search highlight
keymap("n", "<leader>nh", ":nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })

-- Quick save & quit
keymap("n", "<leader>w", ":w<CR>", { silent = true, desc = "Save file" })
keymap("n", "<leader>q", ":q<CR>", { silent = true, desc = "Quit window" })

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", { desc = "Focus left window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Focus right window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Focus bottom window" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Focus top window" })
