-- anvim: TUI dashboard — bootstrap-style, fixed 120×36
-- ponytail: index nav + centered content + single border

local M = {}
M.state = { open = false, selected = 0, items = {}, buf = nil, win = nil }
local alert = require("anvim.status-alert")

local config_m, health_m, project_m, devices_m, tasks_m, system_m

local function lazy_modules()
  local ok
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

-- ── content builder ──
local function build_items(proj, h_results, dev_list)
  local items = {}
  table.insert(items, { type = "header", text = " Tasks" })
  table.insert(items, { type = "task", label = "Run App", task = "run", icon = "▶" })
  table.insert(items, { type = "task", label = "Show Logcat", task = "logcat", icon = "■" })
  table.insert(items, { type = "task", label = "Clean Project", task = "clean", icon = "◐" })
  table.insert(items, { type = "task", label = "Build APK", task = "build", icon = "◆" })
  local has_devices = dev_list and #dev_list > 0
  if has_devices then
    table.insert(items, { type = "header", text = " Devices" })
    for _, d in ipairs(dev_list) do
      local is_active = d.id == devices_m.get_active()
      local prefix = is_active and "●" or "○"
      table.insert(items, { type = "device", label = string.format("%s %s (%s)", prefix, d.model or "device", d.status), device = d })
    end
    table.insert(items, { type = "task", label = "Refresh Devices", task = "devices", icon = "↻" })
  end
  table.insert(items, { type = "header", text = " System" })
  table.insert(items, { type = "task", label = "Check System Tools", task = "check", icon = "⚡" })
  table.insert(items, { type = "header", text = " Info" })
  if h_results then
    for name, r in pairs(h_results.tools) do
      table.insert(items, { type = "health", tool = name, result = r })
    end
  end
  return items
end

local function center(text, w)
  local dw = vim.fn.strdisplaywidth(text)
  return string.rep(" ", math.floor(math.max(0, w - dw) / 2)) .. text
end

-- ── render ──
local W = 120

local function render(buf, items, selected, proj, dev_active)
  local ok, err = pcall(function()
    local lines = {}
    local cur_sel_line = nil

    local function add(l)
      table.insert(lines, l)
    end

    -- vertical padding
    for _ = 1, 3 do add("") end

    -- ── logo / title ──
    add(center("┌─────────────────────────────────────┐", W))
    add(center("│                                     │", W))
    add(center("│           a n v i m                 │", W))
    add(center("│      Android / Flutter Toolkit      │", W))
    add(center("│              v0.1.0                  │", W))
    add(center("│                                     │", W))
    add(center("└─────────────────────────────────────┘", W))
    add("")

    -- ── project + device bar ──
    local info = string.format("  Project: %s (%s)  │  Device: %s",
      proj.name, proj.type, dev_active or "none")
    add(center(info, W))
    add(center(string.rep("─", 60), W))
    add("")

    -- ── items ──
    local idx = 0
    for _, item in ipairs(items) do
      idx = idx + 1
      local is_sel = idx == selected
      local prefix = is_sel and "  → " or "    "

      if item.type == "header" then
        add("")
        add(center("  " .. item.text, W))
      elseif item.type == "task" then
        local txt = prefix .. (item.icon or " ") .. "  " .. item.label
        add(center(txt, W))
        if is_sel then cur_sel_line = #lines end
      elseif item.type == "device" then
        local txt = prefix .. item.label
        add(center(txt, W))
        if is_sel then cur_sel_line = #lines end
      elseif item.type == "health" then
        local icon = item.result.found and "✓" or "✗"
        local loc = item.result.found and item.result.path or ""
        local txt = prefix .. icon .. "  " .. (item.result.label or item.tool) .. " — " .. loc
        add(center(txt, W))
        if is_sel then cur_sel_line = #lines end
      end
    end

    add("")
    add(center(string.rep("─", 60), W))
    add(center("j/k Navigate  Enter Select  ESC Quit  c Check  r Run  l Logcat", W))

    -- apply
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)

    -- snap cursor
    if cur_sel_line then
      pcall(vim.api.nvim_win_set_cursor, vim.fn.bufwinid(buf), { cur_sel_line, 2 })
    end
  end)
  if not ok then
    alert.error("render", err)
  end
end

-- ── public API ──

function M.open()
  local ok, err = pcall(function()
    lazy_modules()
    if M.state.open then
      alert.info("Dashboard already open")
      return
    end

    local height = 42
    local width = 140
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", width = width, height = height,
      col = col, row = row, style = "minimal", border = "single",
    })

    vim.api.nvim_buf_set_name(buf, "anvim://dashboard")
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "anvim-dashboard"
    vim.wo[win].winblend = 10

    M.state.open = true
    M.state.buf = buf
    M.state.win = win
    M.state.selected = 1

    local proj = project_m.detect()
    local dev_list = devices_m.list()
    local h_results = health_m.check_configured(config_m.get().health_check.tools)

    M.state.items = build_items(proj, h_results, dev_list)
    render(buf, M.state.items, M.state.selected, proj, devices_m.get_active())
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
    local proj = M.state.proj or project_m.detect()
    render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active())
  end)
  if not ok then alert.error("nav", err) end
end

local function ensure_tool(name, msg)
  if vim.fn.executable(name) == 0 then
    alert.warn(msg or "Need " .. name .. ".\nRun :AnvimCheck to install.")
    return false
  end
  return true
end

local function ensure_project(proj)
  if not proj or proj.type == "unknown" then
    alert.warn("Open Android (build.gradle) or Flutter (pubspec.yaml) project first.")
    return false
  end
  return true
end

function M.do_logcat()
  if not ensure_tool("adb", "Logcat needs ADB.\nRun :AnvimCheck to install.") then return end
  M.close()
  require("anvim.logcat").open()
end

function M.do_check()
  M.close()
  require("anvim.system_check").interactive()
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
      if item.task == "logcat" then M.do_logcat()
      elseif item.task == "check" then M.do_check()
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
      alert.info("Active: " .. item.device.id)
      local proj = M.state.proj or project_m.detect()
      render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active())
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
