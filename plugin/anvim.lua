-- anvim: plugin loader
if vim.g.loaded_anvim then return end
vim.g.loaded_anvim = 1

require("anvim").setup({})
