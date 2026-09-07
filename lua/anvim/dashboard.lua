-- anvim: TUI dashboard — floating, config-driven, clamp layar kecil
-- nav skip header/health (non-selectable), refresh devices rebuild, sorted health.

local M = {}
M.state = { open = false, selected = 1, items = {}, buf = nil, win = nil, proj = nil }
local alert = require("anvim.status-alert")
local util = require("anvim.util")

local VERSION = "v0.3.0"

local config_m, syscheck_m, project_m, devices_m, tasks_m

local function lazy_modules()
  local ok
  ok, config_m = pcall(require, "anvim.config")
  if not ok then alert.error("dashboard", "config — " .. tostring(config_m)); config_m = nil end
  ok, syscheck_m = pcall(require, "anvim.system_check")
  if not ok then alert.error("dashboard", "system_check — " .. tostring(syscheck_m)); syscheck_m = nil end
  ok, project_m = pcall(require, "anvim.project")
  if not ok then alert.error("dashboard", "project — " .. tostring(project_m)); project_m = nil end
  ok, devices_m = pcall(require, "anvim.devices")
  if not ok then alert.error("dashboard", "devices — " .. tostring(devices_m)); devices_m = nil end
  ok, tasks_m = pcall(require, "anvim.tasks")
  if not ok then alert.error("dashboard", "tasks — " .. tostring(tasks_m)); tasks_m = nil end
  return config_m and syscheck_m and project_m and devices_m and tasks_m
end

local function cfg_dashboard()
  local ok, c = pcall(function() return require("anvim.config").get() end)
  local d = ok and c and c.dashboard or {}
  return {
    width = d.width or 0.8,
    height = d.height or 0.8,
    border = d.border or "rounded",
    winblend = d.winblend or 10,
    min_width = d.min_width or 50,
    min_height = d.min_height or 14,
  }
end

local function is_selectable(item)
  return item and (item.type == "task" or item.type == "device")
end

-- ── content builder ──
local function build_items(proj, h_results, dev_list)
  local items = {}
  table.insert(items, { type = "header", text = "Tasks" })
  table.insert(items, { type = "task", label = "Run App", task = "run", icon = "▶" })
  table.insert(items, { type = "task", label = "Show Logcat", task = "logcat", icon = "■" })
  table.insert(items, { type = "task", label = "Clean Project", task = "clean", icon = "◐" })
  table.insert(items, { type = "task", label = "Build APK", task = "build", icon = "◆" })
  table.insert(items, { type = "header", text = "Devices" })
  if dev_list and #dev_list > 0 then
    for _, d in ipairs(dev_list) do
      local is_active = devices_m and d.id == devices_m.get_active()
      local prefix = is_active and "●" or "○"
      local warn = (d.status ~= "device") and (" [" .. d.status .. "]") or ""
      table.insert(items, { type = "device", label = string.format("%s %s (%s)%s", prefix, d.model or "device", d.id, warn), device = d })
    end
  else
    table.insert(items, { type = "hint", text = "(no devices — hubungkan device / emulator)" })
  end
  table.insert(items, { type = "task", label = "Refresh Devices", task = "devices", icon = "↻" })
  table.insert(items, { type = "header", text = "System" })
  table.insert(items, { type = "task", label = "Check System Tools", task = "check", icon = "⚡" })
  table.insert(items, { type = "header", text = "Info" })
  if h_results then
    for _, name in ipairs(util.sorted_tool_names(h_results)) do
      table.insert(items, { type = "health", tool = name, result = h_results[name] })
    end
  end
  return items
end

local function first_selectable(items)
  for i, it in ipairs(items) do
    if is_selectable(it) then return i end
  end
  return 1
end

local function center(text, w)
  local dw = vim.fn.strdisplaywidth(text)
  return string.rep(" ", math.floor(math.max(0, w - dw) / 2)) .. text
end

-- ── render ──
local function render(buf, items, selected, proj, dev_active, height, width)
  local ok, err = pcall(function()
    local content = {}
    local cur_sel_line = nil

    local function add(l) table.insert(content, l) end

    add(center("a n v i m", width))
    add(center("Android / Flutter Toolkit  " .. VERSION, width))
    add("")
    local info = string.format("Project: %s (%s)  |  Device: %s", proj.name or "?", proj.type or "?", dev_active or "none")
    add(center(info, width))
    if proj.branch and proj.branch ~= "" then
      add(center("Branch: " .. proj.branch, width))
    end
    add(center(string.rep("─", math.min(60, width - 4)), width))
    add("")

    for idx, item in ipairs(items) do
      local is_sel = idx == selected
      local prefix = is_sel and "→ " or "  "
      if item.type == "header" then
        add("")
        add(center("── " .. item.text .. " ──", width))
      elseif item.type == "hint" then
        add(center(item.text, width))
      elseif item.type == "task" then
        local txt = prefix .. (item.icon or " ") .. "  " .. item.label
        add(center(txt, width))
        if is_sel then cur_sel_line = #content end
      elseif item.type == "device" then
        local txt = prefix .. item.label
        add(center(txt, width))
        if is_sel then cur_sel_line = #content end
      elseif item.type == "health" then
        local line = (is_sel and prefix or "  ") .. syscheck_m.format_line(item.tool, item.result)
        add(center(line, width))
      end
    end

    add("")
    add(center(string.rep("─", math.min(60, width - 4)), width))
    add(center("j/k Navigate  Enter Select  x Cancel task  ESC Quit  c Check  r Run  l Logcat", width))

    local vert_pad = math.floor(math.max(0, height - #content) / 2)
    local lines = {}
    for _ = 1, vert_pad do table.insert(lines, "") end
    for _, l in ipairs(content) do table.insert(lines, l) end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    if cur_sel_line then
      pcall(vim.api.nvim_win_set_cursor, vim.fn.bufwinid(buf), { vert_pad + cur_sel_line, 2 })
    end
  end)
  if not ok then
    alert.error("render", err)
  end
end

local function current_geom()
  local d = cfg_dashboard()
  return util.float_geom(d.width, d.height, d.min_width, d.min_height)
end

local function refresh_state()
  local proj = project_m.detect()
  local dev_list = devices_m.list()
  local tools = { "adb", "java", "git", "flutter", "gradle" }
  local ok_c, c = pcall(function() return require("anvim.config").get() end)
  if ok_c and c and c.health_check and c.health_check.tools then tools = c.health_check.tools end
  local h_results = syscheck_m.check_all(tools)
  M.state.items = build_items(proj, h_results, dev_list)
  M.state.proj = proj
  if not is_selectable(M.state.items[M.state.selected]) then
    M.state.selected = first_selectable(M.state.items)
  end
  return proj
end

-- ── public API ──

function M.open()
  local ok, err = pcall(function()
    if not lazy_modules() then return end
    if M.state.open then
      alert.info("Dashboard already open")
      return
    end

    local d = cfg_dashboard()
    local width, height, col, row = util.float_geom(d.width, d.height, d.min_width, d.min_height)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", width = width, height = height,
      col = col, row = row, style = "minimal", border = d.border,
      title = " anvim " .. VERSION .. " ", title_pos = "center",
    })

    vim.api.nvim_buf_set_name(buf, "anvim://dashboard")
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "anvim-dashboard"
    vim.wo[win].winblend = d.winblend

    M.state.open = true
    M.state.buf = buf
    M.state.win = win

    local proj = refresh_state()
    M.state.selected = first_selectable(M.state.items)
    render(buf, M.state.items, M.state.selected, proj, devices_m.get_active(), height, width)
    require("anvim.keymaps.dashboard").set(buf)
  end)
  if not ok then
    alert.error("buka dashboard", err)
  end
end

function M.nav(dir)
  local ok, err = pcall(function()
    local total = #M.state.items
    if total == 0 then return end
    local sel = M.state.selected or 1
    for _ = 1, total do
      sel = sel + dir
      if sel < 1 then sel = total end
      if sel > total then sel = 1 end
      if is_selectable(M.state.items[sel]) then break end
    end
    M.state.selected = sel
    local _, height, _, _ = current_geom()
    local w2 = select(1, current_geom())
    -- ambil width dari geom (urutan w,h)
    local width = w2
    local proj = M.state.proj or project_m.detect()
    render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active(), height, width)
  end)
  if not ok then alert.error("nav", err) end
end

local function ensure_tool(name, msg)
  if vim.fn.executable(name) == 0 then
    alert.warn(msg or ("Need " .. name .. ".\nRun :AnvimCheck to install."))
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
  if not ensure_tool(proj.build_tool == "flutter" and "flutter" or "adb", nil) then return end
  M.close()
  tasks_m.run(proj, "run")
end

function M.do_cancel_task()
  if tasks_m and tasks_m.stop then
    tasks_m.stop()
    alert.info("Task cancelled")
  end
end

function M.select()
  local ok, err = pcall(function()
    local item = M.state.items[M.state.selected]
    if not item then return end
    if not is_selectable(item) then return end
    if item.type == "task" then
      if item.task == "logcat" then M.do_logcat()
      elseif item.task == "check" then M.do_check()
      elseif item.task == "devices" then
        local dl = devices_m.list()
        refresh_state()
        local _, height, _, _ = current_geom()
        local width = select(1, current_geom())
        render(M.state.buf, M.state.items, M.state.selected, M.state.proj, devices_m.get_active(), height, width)
        alert.info("Found " .. #dl .. " device(s) — list refreshed")
      else
        local proj = M.state.proj or project_m.detect()
        if not ensure_project(proj) then return end
        M.close()
        tasks_m.run(proj, item.task)
      end
    elseif item.type == "device" then
      local all = devices_m.list()
      local valid = false
      for _, d in ipairs(all) do if d.id == item.device.id then valid = true break end end
      if not valid then
        alert.warn("Device " .. item.device.id .. " tidak lagi terhubung — refresh")
        refresh_state()
        return
      end
      devices_m.set_active(item.device.id)
      alert.info("Active: " .. item.device.id)
      refresh_state()
      local _, height, _, _ = current_geom()
      local width = select(1, current_geom())
      render(M.state.buf, M.state.items, M.state.selected, M.state.proj, devices_m.get_active(), height, width)
    end
  end)
  if not ok then alert.error("select", err) end
end

function M.close()
  local st = M.state
  if st.win and vim.api.nvim_win_is_valid(st.win) then
    pcall(vim.api.nvim_win_close, st.win, true)
  end
  if st.buf and vim.api.nvim_buf_is_valid(st.buf) then
    pcall(vim.api.nvim_buf_delete, st.buf, { force = true })
  end
  M.state.open = false
  M.state.buf = nil
  M.state.win = nil
  M.state.items = {}
  M.state.selected = 1
  M.state.proj = nil
end

return M
