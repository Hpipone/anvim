-- anvim: TUI dashboard — snacks.nvim style buffer
-- ponytail: real buffer, free cursor, center layout, winblend

local M = {}
M.state = { open = false, buf = nil, win = nil, actions = {} }
local alert = require("anvim.status-alert")

local config_m, health_m, project_m, devices_m, tasks_m

local function modules()
  local ok
  ok, config_m = pcall(require, "anvim.config")
  if not ok then alert.error("dashboard", "config") end
  ok, health_m = pcall(require, "anvim.health")
  if not ok then alert.error("dashboard", "health") end
  ok, project_m = pcall(require, "anvim.project")
  if not ok then alert.error("dashboard", "project") end
  ok, devices_m = pcall(require, "anvim.devices")
  if not ok then alert.error("dashboard", "devices") end
  ok, tasks_m = pcall(require, "anvim.tasks")
  if not ok then alert.error("dashboard", "tasks") end
end

-- ── content builder ──────────────────────────────────────
local function centered(lines, buf_width)
  local out = {}
  local max_w = 0
  for _, l in ipairs(lines) do
    if #l > max_w then max_w = #l end
  end
  local pad = math.floor(math.max(0, buf_width - max_w) / 2)
  for _, l in ipairs(lines) do
    table.insert(out, string.rep(" ", pad) .. l)
  end
  return out
end

local function build_content(proj, dev_active)
  local lines = {}
  local actions = {}

  -- ── logo ──
  local logo = {
    "        ╔═══════════════════════════╗",
    "        ║         a n v i m         ║",
    "        ║  Android Flutter Toolkit  ║",
    "        ║          v0.1.0           ║",
    "        ╚═══════════════════════════╝",
  }
  for _, l in ipairs(logo) do
    table.insert(lines, l)
  end

  -- spacer
  table.insert(lines, "")
  table.insert(lines, "")

  -- ── project & device info ──
  local info = string.format("  Project: %s (%s)  │  Device: %s",
    proj.name, proj.type, dev_active or "none")
  table.insert(lines, info)
  table.insert(lines, "")

  -- ── separator ──
  local sep = string.rep("─", 52)
  table.insert(lines, sep)
  table.insert(lines, "")

  -- ── tasks ──
  local task_start = #lines + 1
  local TASKS = {
    { label = "▶  Run App",         action = "run" },
    { label = "■  Show Logcat",     action = "logcat" },
    { label = "◐  Clean Project",   action = "clean" },
    { label = "◆  Build APK",       action = "build" },
    { label = "⚡ Check System",    action = "check" },
    { label = "↻  Refresh Devices", action = "devices" },
  }
  for _, t in ipairs(TASKS) do
    table.insert(lines, t.label)
    actions[#lines] = t.action
  end
  local task_end = #lines

  table.insert(lines, "")
  table.insert(lines, sep)
  table.insert(lines, "")

  -- ── devices ──
  local dl = devices_m.list()
  if dl and #dl > 0 then
    table.insert(lines, "  Devices:")
    for _, d in ipairs(dl) do
      local is_active = d.id == devices_m.get_active()
      local icon = is_active and " ●" or " ○"
      local lbl = string.format("%s %s (%s)", icon, d.model or "device", d.status)
      table.insert(lines, lbl)
      actions[#lines] = { action = "device", id = d.id }
    end
    table.insert(lines, "")
  end

  -- ── footer keybinds ──
  table.insert(lines, "")
  table.insert(lines, "  j/k  navigate  ·  Enter  select  ·  q  quit")
  table.insert(lines, "  c  check  ·  r  run  ·  l  logcat")

  return lines, actions, task_start, task_end
end

-- ── open ─────────────────────────────────────────────────
function M.open()
  local ok, err = pcall(function()
    modules()
    if M.state.open then
      vim.api.nvim_set_current_win(M.state.win)
      return
    end

    local cfg = config_m.get().dashboard
    local width = math.floor(vim.o.columns * 0.85)
    local height = math.floor(vim.o.lines * 0.85)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", width = width, height = height,
      col = col, row = row, style = "minimal", border = cfg.border or "rounded",
    })

    vim.api.nvim_buf_set_name(buf, "anvim://dashboard")
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "anvim-dashboard"
    vim.wo[win].winblend = 15

    M.state.open = true
    M.state.buf = buf
    M.state.win = win

    local proj = project_m.detect()
    local dev_active = devices_m.get_active()

    local lines, actions = build_content(proj, dev_active)
    M.state.actions = actions

    -- center line count: push content vertical center
    local vert_pad = math.floor(math.max(0, height - #lines) / 2)
    local padded = {}
    for _ = 1, vert_pad do table.insert(padded, "") end
    for _, l in ipairs(centered(lines, width)) do table.insert(padded, l) end
    for _ = 1, vert_pad do table.insert(padded, "") end

    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, padded)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)

    -- keymaps
    require("anvim.keymaps.dashboard").set(buf)

    M.state.proj = proj
    vim.api.nvim_win_set_cursor(win, { vert_pad + 7, 0 }) -- first task
  end)
  if not ok then alert.error("buka dashboard", err) end
end

-- ── Enter handler ────────────────────────────────────────
function M.select()
  local buf = M.state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local line = vim.fn.line(".")
  local action = M.state.actions[line]
  if not action then return end

  if type(action) == "string" then
    if action == "logcat" then
      if vim.fn.executable("adb") == 0 then
        alert.warn("Fitur Logcat butuh ADB.\nJalankan :AnvimCheck buat cek & install otomatis.")
        return
      end
      M.close()
      require("anvim.logcat").open()
    elseif action == "check" then
      M.close()
      vim.schedule(function()
        require("anvim.help_check").interactive()
      end)
    elseif action == "devices" then
      local dl = devices_m.list()
      alert.info("Found " .. #dl .. " device(s)")
    elseif action == "run" or action == "clean" or action == "build" then
      local proj = M.state.proj or project_m.detect()
      if not proj or proj.type == "unknown" then
        alert.warn("Buka project Android/Flutter dulu.\nTask cuma jalan di project terdeteksi.")
        return
      end
      M.close()
      tasks_m.run(proj, action)
    end
  elseif type(action) == "table" and action.action == "device" then
    devices_m.set_active(action.id)
    alert.info("Active device: " .. action.id)
    M.close()
    vim.schedule(function() M.open() end)
  end
end

-- ── close ────────────────────────────────────────────────
function M.close()
  if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
    vim.api.nvim_buf_delete(M.state.buf, { force = true })
  end
  M.state.open = false
  M.state.buf = nil
  M.state.win = nil
  M.state.actions = {}
end

return M
