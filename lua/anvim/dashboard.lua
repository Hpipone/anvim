-- anvim: TUI dashboard — snacks.nvim style buffer
-- ponytail: list navigation + center layout + winblend

local M = {}
M.state = { open = false, selected = 0, items = {}, buf = nil, win = nil }
local alert = require("anvim.status-alert")

local config_m, health_m, project_m, devices_m, tasks_m

local function modules()
  local ok, err
  ok, config_m = pcall(require, "anvim.config")
  if not ok then alert.error("dashboard", "config — " .. tostring(config_m)) end
  ok, health_m = pcall(require, "anvim.health")
  if not ok then alert.error("dashboard", "health — " .. tostring(health_m)) end
  ok, project_m = pcall(require, "anvim.project")
  if not ok then alert.error("dashboard", "project — " .. tostring(project_m)) end
  ok, devices_m = pcall(require, "anvim.devices")
  if not ok then alert.error("dashboard", "devices — " .. tostring(devices_m)) end
  ok, tasks_m = pcall(require, "anvim.tasks")
  if not ok then alert.error("dashboard", "tasks — " .. tostring(tasks_m)) end
end

-- ponytail: content builder (sama kayak sebelumnya)
local function build_items(proj, h_results, dev_list)
  local items = {}

  table.insert(items, { type = "header", text = " Tasks" })
  table.insert(items, { type = "task", label = "Run App", task = "run", icon = "▶" })
  table.insert(items, { type = "task", label = "Show Logcat", task = "logcat", icon = "■" })
  table.insert(items, { type = "task", label = "Clean Project", task = "clean", icon = "◐" })
  table.insert(items, { type = "task", label = "Build APK", task = "build", icon = "◆" })

  local has_devices = dev_list and #dev_list > 0
  if has_devices then
    table.insert(items, { type = "separator", text = " Devices" })
    for _, d in ipairs(dev_list) do
      local is_active = d.id == devices_m.get_active()
      local prefix = is_active and "●" or "○"
      table.insert(items, { type = "device", label = string.format("%s %s (%s)", prefix, d.model or "device", d.status), device = d })
    end
    table.insert(items, { type = "task", label = "Refresh Devices", task = "devices", icon = "↻" })
  end

  table.insert(items, { type = "separator", text = " System" })
  table.insert(items, { type = "task", label = "Check System Health", task = "check", icon = "⚡" })

  table.insert(items, { type = "separator", text = " Info" })
  if h_results then
    for name, r in pairs(h_results.tools) do
      table.insert(items, { type = "health", tool = name, result = r })
    end
  end

  return items
end

local function centered_line(text, buf_width)
  local display_width = vim.fn.strdisplaywidth(text)
  local pad = math.floor(math.max(0, buf_width - display_width) / 2)
  return string.rep(" ", pad) .. text
end

local function render(buf, items, selected, proj, dev_active, width)
  local ok, err = pcall(function()
    local lines = {}
    local highlights = {}

    local function add(line, hl)
      table.insert(lines, line)
      table.insert(highlights, { line = #lines, hl = hl })
    end

    -- empty lines top padding (vert center)
    local content_h = 5 + #items + 6 + (#items > 0 and 1 or 0)
    local cfg = config_m.get().dashboard
    local height = math.floor(vim.o.lines * cfg.height)
    local vert_pad = math.floor(math.max(0, height - content_h) / 2)
    for _ = 1, vert_pad do add("", nil) end

    local empty = vim.fn.has("gui_running") == 1 and " " or " "

    -- ── logo ──
    local logo_lines = {
      string.rep(empty, 4) .. "╔═══════════════════════════╗",
      string.rep(empty, 4) .. "║         a n v i m         ║",
      string.rep(empty, 4) .. "║  Android Flutter Toolkit  ║",
      string.rep(empty, 4) .. "║          v0.1.0           ║",
      string.rep(empty, 4) .. "╚═══════════════════════════╝",
    }
    for _, l in ipairs(logo_lines) do
      add(centered_line(l, width), "Title")
    end
    add("", nil)
    add("", nil)

    -- info
    local info = string.format("  Project: %s (%s)  │  Device: %s",
      proj.name, proj.type, dev_active or "none")
    add(centered_line(info, width), "String")
    add("", nil)
    add(centered_line(string.rep("─", 52), width), "NonText")
    add("", nil)

    -- items
    local idx = 0
    for _, item in ipairs(items) do
      idx = idx + 1
      local is_sel = idx == selected
      local prefix = is_sel and " →" or "  "
      local line_text
      local line_hl

      if item.type == "header" then
        add("", nil)
        line_text = centered_line(item.text, width)
        add(line_text, "Type")
      elseif item.type == "separator" then
        line_text = centered_line("  " .. item.text, width)
        add(line_text, "NonText")
      elseif item.type == "task" then
        line_text = centered_line(prefix .. " " .. (item.icon or " ") .. " " .. item.label, width)
        add(line_text, is_sel and "MoreMsg" or "Normal")
      elseif item.type == "device" then
        line_text = centered_line(prefix .. " " .. item.label, width)
        add(line_text, is_sel and "MoreMsg" or "Normal")
      elseif item.type == "health" then
        local icon = item.result.found and "✓" or "✗"
        local hl = is_sel and "MoreMsg" or (item.result.found and "String" or "Error")
        local txt = string.format(" %s %s", icon, health_m.format_line(item.tool, item.result))
        line_text = centered_line(prefix .. txt, width)
        add(line_text, hl)
      end
    end

    add("", nil)
    add(centered_line(string.rep("─", 52), width), "NonText")
    add(centered_line(" j/k Navigate  Enter Select  ESC Quit  c Check  r Run  l Logcat", width), "Comment")

    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)

    -- cursor pos
    local cursor_line = #lines
    for i = 1, #lines do
      if highlights[i] and highlights[i].hl == "MoreMsg" then
        cursor_line = i
        break
      end
    end
    vim.api.nvim_win_set_cursor(vim.fn.bufwinid(buf), { cursor_line, 0 })
  end)
  if not ok then
    alert.error("render", err)
  end
end

function M.open()
  local ok, err = pcall(function()
    modules()

    if M.state.open then
      alert.info("Dashboard already open")
      return
    end

    local cfg = config_m.get().dashboard
    local width = math.floor(vim.o.columns * cfg.width)
    local height = math.floor(vim.o.lines * cfg.height)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", width = width, height = height,
      col = col, row = row, style = "minimal", border = cfg.border,
    })

    vim.api.nvim_buf_set_name(buf, "anvim://dashboard")
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "anvim-dashboard"
    vim.wo[win].winblend = 15

    M.state.open = true
    M.state.buf = buf
    M.state.win = win
    M.state.selected = 1

    local proj = project_m.detect()
    local dev_list = devices_m.list()
    local h_results = health_m.check_configured(config_m.get().health_check.tools)

    M.state.items = build_items(proj, h_results, dev_list)
    render(buf, M.state.items, M.state.selected, proj, devices_m.get_active(), width)

    require("anvim.keymaps.dashboard").set(buf)

    M.state.proj = proj
  end)
  if not ok then
    alert.error("buka dashboard", err)
  end
end

function M.nav(dir)
  local ok, err = pcall(function()
    local total = #M.state.items
    M.state.selected = M.state.selected + dir
    if M.state.selected < 1 then M.state.selected = total end
    if M.state.selected > total then M.state.selected = 1 end
    local cfg = config_m.get().dashboard
    local width = math.floor(vim.o.columns * cfg.width)
    local proj = M.state.proj or project_m.detect()
    render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active(), width)
  end)
  if not ok then alert.error("nav", err) end
end

-- ponytail: cek prereq dulu sebelum close dashboard
local function ensure_tool(name, msg)
  if vim.fn.executable(name) == 0 then
    alert.warn(msg or "Butuh " .. name .. ".\nJalankan :AnvimCheck buat cek & install otomatis.")
    return false
  end
  return true
end

local function ensure_project(proj)
  if not proj or proj.type == "unknown" then
    alert.warn("Buka project Android (build.gradle) atau Flutter (pubspec.yaml) dulu.\nTask kaya build/clean/run cuma jalan di project yang terdeteksi.")
    return false
  end
  return true
end

function M.do_logcat()
  if not ensure_tool("adb", "Fitur Logcat butuh ADB (Android Debug Bridge).\nJalankan :AnvimCheck buat cek & install otomatis.") then return end
  M.close()
  require("anvim.logcat").open()
end

function M.do_check()
  M.close()
  require("anvim.help_check").interactive()
end

function M.do_run()
  local proj = project_m.detect()
  if not ensure_project(proj) then return end
  M.close()
  tasks_m.run(proj, "run")
end

function M.select()
  local ok, err = pcall(function()
    local item = M.state.items[M.state.selected]
    if not item then return end
    if item.type == "task" then
      if item.task == "logcat" then
        M.do_logcat()
      elseif item.task == "check" then
        M.do_check()
      elseif item.task == "devices" then
        local dl = devices_m.list()
        alert.info("Found " .. #dl .. " device(s)")
      else
        local proj = M.state.proj or project_m.detect()
        if not ensure_project(proj) then return end
        M.close()
        tasks_m.run(proj, item.task)
      end
    elseif item.type == "device" then
      devices_m.set_active(item.device.id)
      alert.info("Active device: " .. item.device.id)
      local proj = M.state.proj or project_m.detect()
      local cfg = config_m.get().dashboard
      local width = math.floor(vim.o.columns * cfg.width)
      render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active(), width)
    end
  end)
  if not ok then alert.error("select", err) end
end

function M.close()
  if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
    vim.api.nvim_buf_delete(M.state.buf, { force = true })
  end
  M.state.open = false
  M.state.buf = nil
  M.state.win = nil
end

return M
