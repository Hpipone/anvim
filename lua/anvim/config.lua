-- anvim: config
-- ponytail: minimal config with sensible defaults

local M = {}

M.defaults = {
  dashboard = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
  health_check = {
    auto = true,
    tools = { "adb", "java", "git", "flutter", "gradle" },
  },
  logcat = {
    max_lines = 5000,
    filter_default = "I",
  },
  tasks = {
    timeout_ms = 300000,
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
  return M.config
end

function M.get()
  return M.config or M.defaults
end

return M
