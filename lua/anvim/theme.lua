-- anvim: theme — highlight groups + colorscheme respect.
-- Semua UI (dashboard, system check) pakai group ini agar konsisten.
-- User bisa override: vim.api.nvim_set_hl(0, "AnvimSelected", {...})

local M = {}

local GROUPS = {
  AnvimTitle = "Title",
  AnvimHeader = "Identifier",
  AnvimSelected = "Visual",
  AnvimOk = "DiffAdd",
  AnvimWarn = "DiffChange",
  AnvimError = "DiffDelete",
  AnvimHint = "Comment",
}

function M.setup()
  for group, fallback in pairs(GROUPS) do
    pcall(vim.api.nvim_set_hl, 0, group, { link = fallback, default = true })
  end
end

function M.hl(buf, line0, group, col_start, col_end)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  pcall(vim.api.nvim_buf_add_highlight, buf, -1, group, line0, col_start or 0, col_end or -1)
end

M.setup()

return M
