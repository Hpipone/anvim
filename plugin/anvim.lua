-- anvim: vim-plug loader
-- Neovim auto-sources ini untuk vim-plug.
-- lazy.nvim skip plugin/ files, jadi ini cuma kepanggil pas vim-plug.
if vim.g.anvim_loaded then return end
vim.g.anvim_loader = "vim-plug"
require("anvim").setup({})
