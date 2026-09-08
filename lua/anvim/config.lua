-- anvim: config
-- ponytail: minimal config with sensible defaults

local M = {}

M.defaults = {
  version = "1.3.1",
  dashboard = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
    winblend = 10,
    min_width = 50,
    min_height = 14,
  },
  health_check = {
    auto = true,
    tools = { "adb", "java", "git", "flutter", "gradle", "scrcpy" },
  },
  logcat = {
    max_lines = 5000,
    filter_default = "I",
    no_dashboard_on_close = true,
  },
  tasks = {
    timeout_ms = 300000,
    custom = {},
  },
  install = {
    dir = nil, -- default ~/.anvim/tools (via util.tools_dir())
    bin_dir = nil, -- default ~/.local/bin (via util.local_bin())
  },
  detect = {
    extra_dirs = {}, -- mis. { "~/tools", "/opt/android" } (+ bawaan ~/Downloads ~/Documents)
    max_depth = 3,
    cache_ttl = 300, -- detik
  },
  emulator = {
    boot_timeout_ms = 120000,
  },
  scrcpy = {
    replace_emulator = true,
    max_size = 1920,
    bit_rate = "8M",
    audio = false,
    stay_awake = true,
    turn_screen_off = true,
    record_dir = "~/Videos",
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
