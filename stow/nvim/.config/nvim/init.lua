-- Neovim configuration (init.lua)
-- Managed by dotfiles (GNU Stow)
-- Plugin manager: lazy.nvim

-- =============================================================================
-- Bootstrap lazy.nvim
-- =============================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- =============================================================================
-- Options
-- =============================================================================
local opt = vim.opt
local g = vim.g

-- Leader key (must be set before lazy.nvim)
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
opt.colorcolumn = "100"

-- Wayland / System Clipboard Integration
opt.clipboard = "unnamedplus"

-- Split behavior
opt.splitright = true
opt.splitbelow = true

-- Update time (faster CursorHold, better UX)
opt.updatetime = 250
opt.timeoutlen = 300

-- =============================================================================
-- Keymaps (base, no plugins required)
-- =============================================================================
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

-- Better indenting in visual mode (keep selection)
keymap("v", "<", "<gv", { desc = "Indent left" })
keymap("v", ">", ">gv", { desc = "Indent right" })

-- Move lines up/down in visual mode
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- =============================================================================
-- Plugins (lazy.nvim)
-- =============================================================================
require("lazy").setup({

    -- -------------------------------------------------------------------------
    -- Colorscheme
    -- -------------------------------------------------------------------------
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        config = function()
            require("catppuccin").setup({
                flavour = "mocha",
                integrations = {
                    treesitter = true,
                    telescope = { enabled = true },
                    neo_tree = true,
                    mason = true,
                    which_key = true,
                    gitsigns = true,
                    cmp = true,
                    native_lsp = { enabled = true },
                },
            })
            vim.cmd.colorscheme("catppuccin")
        end,
    },

    -- -------------------------------------------------------------------------
    -- Statusline
    -- -------------------------------------------------------------------------
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("lualine").setup({
                options = {
                    theme = "catppuccin",
                    component_separators = { left = "", right = "" },
                    section_separators = { left = "", right = "" },
                },
            })
        end,
    },

    -- -------------------------------------------------------------------------
    -- Syntax Highlighting (Treesitter)
    -- -------------------------------------------------------------------------
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "lua", "python", "c", "cpp",
                    "bash", "yaml", "json", "toml",
                    "markdown", "vim", "vimdoc",
                },
                auto_install = true,
                highlight = { enable = true },
                indent = { enable = true },
            })
        end,
    },

    -- -------------------------------------------------------------------------
    -- LSP
    -- -------------------------------------------------------------------------
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end,
    },
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls",    -- Lua
                    "pyright",   -- Python
                    "clangd",    -- C / C++
                    "bashls",    -- Bash
                    "yamlls",    -- YAML
                    "jsonls",    -- JSON
                },
                automatic_installation = true,
            })

            local lspconfig = require("lspconfig")
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            -- Shared on_attach: keybindings available once LSP attaches
            local on_attach = function(_, bufnr)
                local opts = { buffer = bufnr, silent = true }
                keymap("n", "gd",         vim.lsp.buf.definition,      vim.tbl_extend("force", opts, { desc = "LSP: Go to definition" }))
                keymap("n", "gr",         vim.lsp.buf.references,      vim.tbl_extend("force", opts, { desc = "LSP: References" }))
                keymap("n", "gD",         vim.lsp.buf.declaration,     vim.tbl_extend("force", opts, { desc = "LSP: Go to declaration" }))
                keymap("n", "gi",         vim.lsp.buf.implementation,  vim.tbl_extend("force", opts, { desc = "LSP: Go to implementation" }))
                keymap("n", "K",          vim.lsp.buf.hover,           vim.tbl_extend("force", opts, { desc = "LSP: Hover documentation" }))
                keymap("n", "<leader>rn", vim.lsp.buf.rename,          vim.tbl_extend("force", opts, { desc = "LSP: Rename symbol" }))
                keymap("n", "<leader>ca", vim.lsp.buf.code_action,     vim.tbl_extend("force", opts, { desc = "LSP: Code action" }))
                keymap("n", "<leader>d",  vim.diagnostic.open_float,   vim.tbl_extend("force", opts, { desc = "LSP: Show diagnostics" }))
                keymap("n", "[d",         vim.diagnostic.goto_prev,    vim.tbl_extend("force", opts, { desc = "LSP: Previous diagnostic" }))
                keymap("n", "]d",         vim.diagnostic.goto_next,    vim.tbl_extend("force", opts, { desc = "LSP: Next diagnostic" }))
            end

            -- Per-server setup
            local servers = { "pyright", "clangd", "bashls", "yamlls", "jsonls" }
            for _, server in ipairs(servers) do
                lspconfig[server].setup({ on_attach = on_attach, capabilities = capabilities })
            end

            -- lua_ls needs special settings to understand Neovim's globals
            lspconfig.lua_ls.setup({
                on_attach = on_attach,
                capabilities = capabilities,
                settings = {
                    Lua = {
                        diagnostics = { globals = { "vim" } },
                        workspace = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
                        telemetry = { enable = false },
                    },
                },
            })
        end,
    },
    { "neovim/nvim-lspconfig" },

    -- -------------------------------------------------------------------------
    -- Completion
    -- -------------------------------------------------------------------------
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            "rafamadriz/friendly-snippets",
        },
        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")
            require("luasnip.loaders.from_vscode").lazy_load()

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-k>"]   = cmp.mapping.select_prev_item(),
                    ["<C-j>"]   = cmp.mapping.select_next_item(),
                    ["<C-b>"]   = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"]   = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<C-e>"]   = cmp.mapping.abort(),
                    ["<CR>"]    = cmp.mapping.confirm({ select = false }),
                    ["<Tab>"]   = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                    { name = "buffer" },
                    { name = "path" },
                }),
            })
        end,
    },

    -- -------------------------------------------------------------------------
    -- Telescope (Fuzzy Finder)
    -- -------------------------------------------------------------------------
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        config = function()
            local telescope = require("telescope")
            telescope.setup({
                defaults = {
                    prompt_prefix = "❯ ",
                    selection_caret = "  ",
                    path_display = { "truncate" },
                },
            })
            telescope.load_extension("fzf")

            local builtin = require("telescope.builtin")
            keymap("n", "<leader>ff", builtin.find_files,               { desc = "Telescope: Find files" })
            keymap("n", "<leader>fg", builtin.live_grep,                { desc = "Telescope: Live grep" })
            keymap("n", "<leader>fb", builtin.buffers,                  { desc = "Telescope: Buffers" })
            keymap("n", "<leader>fh", builtin.help_tags,                { desc = "Telescope: Help tags" })
            keymap("n", "<leader>fr", builtin.oldfiles,                 { desc = "Telescope: Recent files" })
            keymap("n", "<leader>fd", builtin.diagnostics,              { desc = "Telescope: Diagnostics" })
        end,
    },

    -- -------------------------------------------------------------------------
    -- File Tree (Neo-tree)
    -- -------------------------------------------------------------------------
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        config = function()
            require("neo-tree").setup({
                window = { width = 30 },
                filesystem = {
                    filtered_items = {
                        visible = true,
                        hide_dotfiles = false,
                        hide_gitignored = false,
                    },
                    follow_current_file = { enabled = true },
                },
            })
            keymap("n", "<leader>e", ":Neotree toggle<CR>", { silent = true, desc = "Toggle file tree" })
            keymap("n", "<leader>E", ":Neotree reveal<CR>", { silent = true, desc = "Reveal file in tree" })
        end,
    },

    -- -------------------------------------------------------------------------
    -- Git Signs
    -- -------------------------------------------------------------------------
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require("gitsigns").setup({
                signs = {
                    add          = { text = "▎" },
                    change       = { text = "▎" },
                    delete       = { text = "" },
                    topdelete    = { text = "" },
                    changedelete = { text = "▎" },
                },
                on_attach = function(bufnr)
                    local gs = package.loaded.gitsigns
                    local opts = { buffer = bufnr }
                    keymap("n", "]h", gs.next_hunk,        vim.tbl_extend("force", opts, { desc = "Git: Next hunk" }))
                    keymap("n", "[h", gs.prev_hunk,        vim.tbl_extend("force", opts, { desc = "Git: Prev hunk" }))
                    keymap("n", "<leader>gp", gs.preview_hunk, vim.tbl_extend("force", opts, { desc = "Git: Preview hunk" }))
                    keymap("n", "<leader>gr", gs.reset_hunk,   vim.tbl_extend("force", opts, { desc = "Git: Reset hunk" }))
                    keymap("n", "<leader>gb", gs.blame_line,   vim.tbl_extend("force", opts, { desc = "Git: Blame line" }))
                end,
            })
        end,
    },

    -- -------------------------------------------------------------------------
    -- Which-key (Keybinding hints)
    -- -------------------------------------------------------------------------
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function()
            require("which-key").setup()
            require("which-key").add({
                { "<leader>f", group = "Find (Telescope)" },
                { "<leader>g", group = "Git" },
                { "<leader>c", group = "Code (LSP)" },
            })
        end,
    },

    -- -------------------------------------------------------------------------
    -- Auto pairs & surrounds
    -- -------------------------------------------------------------------------
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup({
                check_ts = true, -- Treesitter-aware pairing
            })
            -- Integrate with nvim-cmp
            local cmp_autopairs = require("nvim-autopairs.completion.cmp")
            require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end,
    },

    -- -------------------------------------------------------------------------
    -- Comment toggling
    -- -------------------------------------------------------------------------
    {
        "numToStr/Comment.nvim",
        event = "VeryLazy",
        config = function()
            require("Comment").setup()
        end,
    },

}, {
    -- lazy.nvim UI settings
    ui = { border = "rounded" },
    checker = { enabled = false }, -- disable auto update check
})
