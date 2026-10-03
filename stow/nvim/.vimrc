" .vimrc - Traditional Vim fallback configuration
" Matches settings in ~/.config/nvim/init.lua

set nocompatible
syntax on
filetype plugin indent on

" Line numbers
set number
set relativenumber

" Tabs & Indentation
set tabstop=4
set shiftwidth=4
set expandtab
set smartindent

" Search
set ignorecase
set smartcase
set hlsearch
set incsearch

" Visuals
set termguicolors
set cursorline
set scrolloff=8
set nowrap

" System clipboard (where supported in terminal)
set clipboard=unnamedplus

" Leader key
let mapleader = " "

" Keymaps
nnoremap <leader>nh :nohlsearch<CR>
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
