-- anvim: TUI dashboard — floating, config-driven, clamp layar kecil
-- nav skip header/health (non-selectable), refresh devices rebuild, sorted health.

local M = {}
M.state = { open = false, selected = 1, items = {}, buf = nil, win = nil, proj = nil }
local alert = require("anvim.status-alert")
local util = require("anvim.util")
pcall(require, "anvim.theme")

local VERSION = "v1.2.0"

local config_m, syscheck_m, project_m, devices_m, tasks_m, emulator_m, flutter_m, scrcpy_m

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
  ok, emulator_m = pcall(require, "anvim.emulator")
  if not ok then emulator_m = nil end
  ok, flutter_m = pcall(require, "anvim.flutter")
  if not ok then flutter_m = nil end
  ok, scrcpy_m = pcall(require, "anvim.scrcpy")
  if not ok then scrcpy_m = nil end
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
  return item and (item.type == "task" or item.type == "device" or item.type == "avd" or item.type == "custom" or item.type == "scrcpy")
end

local function custom_tasks()
  local ok, c = pcall(function() return require("anvim.config").get() end)
  if ok and c and c.tasks and type(c.tasks.custom) == "table" then
    return c.tasks.custom
  end
  return {}
end

--- Ringkasan diagnostics LSP untuk project (nil jika tidak ada).
local function diag_line(proj)
  local ok, res = pcall(function()
    if not (vim.diagnostic and vim.diagnostic.get) then return nil end
    local diags = vim.diagnostic.get(nil)
    if not diags or #diags == 0 then return nil end
    local sev_ok, sev = pcall(function() return vim.diagnostic.severity end)
    local e, w = 0, 0
    local root = (proj and proj.root) or ""
    for _, d in ipairs(diags) do
      local in_proj = true
      if root ~= "" and d.bufnr then
        local name_ok, name = pcall(vim.api.nvim_buf_get_name, d.bufnr)
        in_proj = name_ok and name:sub(1, #root) == root
      end
      if in_proj then
        if sev_ok and sev and d.severity == sev.ERROR then e = e + 1
        elseif sev_ok and sev and d.severity == sev.WARN then w = w + 1
        else w = w + 1 end
      end
    end
    if e == 0 and w == 0 then return nil end
    return string.format("Diagnostics: E%d W%d", e, w)
  end)
  if ok then return res end
  return nil
end

-- ── content builder ──
local function build_items(proj, h_results, dev_list, avd_info, fdevs, scrcpy_info, show_emulators, scrcpy_hint)
  local items = {}
  table.insert(items, { type = "header", text = "Tasks" })
  table.insert(items, { type = "task", label = "Run App", task = "run", icon = "▶" })
  table.insert(items, { type = "task", label = "Show Logcat", task = "logcat", icon = "■" })
  table.insert(items, { type = "task", label = "Clean Project", task = "clean", icon = "◐" })
  table.insert(items, { type = "task", label = "Build APK", task = "build", icon = "◆" })
  table.insert(items, { type = "task", label = "Run Tests", task = "test", icon = "◈" })
  for _, c in ipairs(custom_tasks()) do
    if type(c.label) == "string" and type(c.cmd) == "table" then
      table.insert(items, { type = "custom", label = c.label, cmd = c.cmd, icon = "★" })
    end
  end
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
  if scrcpy_info and #scrcpy_info > 0 then
    table.insert(items, { type = "header", text = "Scrcpy" })
    for _, s in ipairs(scrcpy_info) do
      if s.running then
        table.insert(items, { type = "scrcpy", label = string.format("● %s (%s) — mirroring", s.model or "device", s.id), scrcpy = s })
      else
        table.insert(items, { type = "scrcpy", label = string.format("○ %s (%s) — mirror", s.model or "device", s.id), scrcpy = s })
      end
    end
    table.insert(items, { type = "task", label = "Scrcpy… (mirror/record/stop)", task = "scrcpy", icon = "◉" })
  elseif scrcpy_hint then
    table.insert(items, { type = "hint", text = "(scrcpy: mirror HP — c → check untuk install)" })
  end
  if show_emulators ~= false then
    table.insert(items, { type = "header", text = "Emulators" })
    if avd_info and avd_info.loading then
      table.insert(items, { type = "hint", text = "(loading…)" })
    elseif avd_info and #avd_info > 0 then
      for _, a in ipairs(avd_info) do
        if a.running_id then
          local is_active = devices_m and a.running_id == devices_m.get_active()
          local prefix = is_active and "●" or "○"
          table.insert(items, { type = "avd", label = string.format("%s %s (%s)", prefix, a.name, a.running_id), avd = a })
        else
          table.insert(items, { type = "avd", label = string.format("○ %s (stopped)", a.name), avd = a })
        end
      end
    else
      table.insert(items, { type = "hint", text = "(no AVD — buat via Android Studio Device Manager)" })
    end
    table.insert(items, { type = "task", label = "Launch Emulator…", task = "emulator", icon = "▶" })
    table.insert(items, { type = "task", label = "Kill Emulator…", task = "emulator_kill", icon = "■" })
  end
  if fdevs and #fdevs > 0 then
    table.insert(items, { type = "header", text = "Flutter Targets" })
    for _, f in ipairs(fdevs) do
      table.insert(items, { type = "hint", text = string.format("%s [%s] (%s)", f.name, f.id, f.platform) })
    end
  end
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
    local marks = {}
    local cur_sel_line = nil

    local function add(l, g)
      table.insert(content, l)
      table.insert(marks, g)
    end

    add(center("a n v i m", width), "AnvimTitle")
    add(center("Android / Flutter Toolkit  " .. VERSION, width))
    add("")
    local info = string.format("Project: %s (%s)  |  Device: %s", proj.name or "?", proj.type or "?", dev_active or "none")
    add(center(info, width))
    if proj.branch and proj.branch ~= "" then
      add(center("Branch: " .. proj.branch, width))
    end
    local diag = diag_line(proj)
    if diag then
      add(center(diag, width), (diag:find("E[1-9]") and "AnvimError" or "AnvimWarn"))
    end
    add(center(string.rep("─", math.min(60, width - 4)), width))
    add("")

    for idx, item in ipairs(items) do
      local is_sel = idx == selected
      local prefix = is_sel and "→ " or "  "
      if item.type == "header" then
        add("")
        add(center("── " .. item.text .. " ──", width), "AnvimHeader")
      elseif item.type == "hint" then
        add(center(item.text, width), "AnvimHint")
      elseif item.type == "task" then
        local txt = prefix .. (item.icon or " ") .. "  " .. item.label
        add(center(txt, width), is_sel and "AnvimSelected" or nil)
        if is_sel then cur_sel_line = #content end
      elseif item.type == "custom" then
        local txt = prefix .. (item.icon or "★") .. "  " .. item.label
        add(center(txt, width), is_sel and "AnvimSelected" or nil)
        if is_sel then cur_sel_line = #content end
      elseif item.type == "device" then
        local txt = prefix .. item.label
        add(center(txt, width), is_sel and "AnvimSelected" or nil)
        if is_sel then cur_sel_line = #content end
      elseif item.type == "avd" then
        local txt = prefix .. "▣  " .. item.label
        add(center(txt, width), is_sel and "AnvimSelected" or nil)
        if is_sel then cur_sel_line = #content end
      elseif item.type == "scrcpy" then
        local txt = prefix .. "◉  " .. item.label
        add(center(txt, width), is_sel and "AnvimSelected" or nil)
        if is_sel then cur_sel_line = #content end
      elseif item.type == "health" then
        local line = (is_sel and prefix or "  ") .. syscheck_m.format_line(item.tool, item.result)
        local g = is_sel and "AnvimSelected"
          or (item.result.status == "ok" and "AnvimOk"
            or item.result.status == "old" and "AnvimWarn" or "AnvimError")
        add(center(line, width), g)
      end
    end

    add("")
    add(center(string.rep("─", math.min(60, width - 4)), width))
    add(center("j/k Move  Enter Select  R Rerun  x Cancel  e Emu  m Mirror  t Test  q Quit  c Check  r Run  l Log", width))

    local vert_pad = math.floor(math.max(0, height - #content) / 2)
    local lines = {}
    for _ = 1, vert_pad do table.insert(lines, "") end
    for _, l in ipairs(content) do table.insert(lines, l) end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    for i, g in ipairs(marks) do
      if g then
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, g, vert_pad + i - 1, 0, -1)
      end
    end

    if cur_sel_line then
      M.state.sel_line = vert_pad + cur_sel_line
      pcall(vim.api.nvim_win_set_cursor, vim.fn.bufwinid(buf), { vert_pad + cur_sel_line, 2 })
    else
      M.state.sel_line = nil
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

local function refresh_state(slow)
  if slow == nil then slow = true end
  local proj = project_m.detect()
  local dev_list = devices_m.list()
  local tools = { "adb", "java", "git", "flutter", "gradle" }
  local ok_c, c = pcall(function() return require("anvim.config").get() end)
  if ok_c and c and c.health_check and c.health_check.tools then tools = c.health_check.tools end
  local h_results = syscheck_m.check_all(tools)
  -- AVD info: lambat (spawn emulator binary + adb per device) → fase slow saja
  local avd_info = {}
  if slow and emulator_m then
    local ok_e, avds = pcall(emulator_m.list_avds)
    if ok_e and avds then
      local rmap = {}
      pcall(function() rmap = emulator_m.running_map(dev_list) or {} end)
      for _, name in ipairs(avds) do
        table.insert(avd_info, { name = name, running_id = rmap[name] })
      end
    end
  elseif emulator_m then
    avd_info = { loading = true }
  end
  -- Flutter targets: `flutter devices` lambat (detik) → fase slow saja
  local fdevs = {}
  if slow and flutter_m and proj.type == "flutter" then
    pcall(function() fdevs = flutter_m.list() or {} end)
  end
  -- Scrcpy: gantikan emulator bila ada + replace_emulator (default true)
  local scrcpy_info = {}
  local show_emulators = true
  local scrcpy_hint = false
  if scrcpy_m then
    local found = false
    pcall(function() found = scrcpy_m.find_binary() ~= nil end)
    if found then
      for _, d in ipairs(dev_list) do
        if d.status == "device" then
          local running = false
          pcall(function() running = scrcpy_m.is_running(d.id) end)
          table.insert(scrcpy_info, { id = d.id, model = d.model, running = running })
        end
      end
      local rep = true
      pcall(function()
        local c = require("anvim.config").get()
        if c and c.scrcpy and c.scrcpy.replace_emulator ~= nil then
          rep = c.scrcpy.replace_emulator
        end
      end)
      show_emulators = not rep
    else
      -- scrcpy belum install tapi ada device online → kasih petunjuk
      for _, d in ipairs(dev_list) do
        if d.status == "device" then scrcpy_hint = true break end
      end
    end
  end
  M.state.items = build_items(proj, h_results, dev_list, avd_info, fdevs, scrcpy_info, show_emulators, scrcpy_hint)
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

    pcall(vim.api.nvim_buf_set_name, buf, "anvim://dashboard")
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "anvim-dashboard"
    vim.wo[win].winblend = d.winblend

    M.state.open = true
    M.state.buf = buf
    M.state.win = win

    -- fase cepat: tanpa section lambat → window langsung tampil
    local proj = refresh_state(false)
    M.state.selected = first_selectable(M.state.items)
    render(buf, M.state.items, M.state.selected, proj, devices_m.get_active(), height, width)
    require("anvim.keymaps.dashboard").set(buf)
    -- fase lambat (emulator/flutter): susulkan tanpa blokir open
    local open_buf, open_win = buf, win
    vim.schedule(function()
      if not M.state.open or M.state.buf ~= open_buf or M.state.win ~= open_win then return end
      local ok2, proj2 = pcall(refresh_state, true)
      if not ok2 then return end
      if not M.state.open or M.state.buf ~= open_buf then return end
      if not is_selectable(M.state.items[M.state.selected]) then
        M.state.selected = first_selectable(M.state.items)
      end
      local w2, h2 = current_geom()
      render(open_buf, M.state.items, M.state.selected, proj2, devices_m.get_active(), h2, w2)
    end)
    -- kunci cursor: snap balik ke baris selected (hanya navigasi atas/bawah)
    pcall(vim.api.nvim_create_augroup, "AnvimDashboard", { clear = true })
    pcall(vim.api.nvim_create_autocmd, "CursorMoved", {
      group = "AnvimDashboard",
      buffer = buf,
      callback = function() M._snap() end,
    })
    -- user nutup paksa (:bd/:q) tanpa M.close() → bersihkan state anti-stuck
    pcall(vim.api.nvim_create_autocmd, "BufWipeout", {
      group = "AnvimDashboard",
      buffer = buf,
      callback = function()
        M.state.open = false
        M.state.buf = nil
        M.state.win = nil
        M.state.items = {}
        M.state.selected = 1
        M.state.proj = nil
        M.state.sel_line = nil
      end,
    })

    -- health_check.auto: peringatkan tool wajib yang hilang (sekali per buka)
    pcall(function()
      local cfg = config_m.get()
      if cfg and cfg.health_check and cfg.health_check.auto then
        local missing, outdated = {}, {}
        for _, it in ipairs(M.state.items) do
          if it.type == "health" and it.result then
            if it.result.status == "missing" and not it.result.optional then
              table.insert(missing, it.result.label or it.tool)
            elseif it.result.status == "old" then
              table.insert(outdated, it.result.label or it.tool)
            end
          end
        end
        if #missing > 0 then
          alert.warn("Missing: " .. table.concat(missing, ", ") .. " — tekan c untuk install.")
        elseif #outdated > 0 then
          alert.warn("Outdated: " .. table.concat(outdated, ", ") .. " — pertimbangkan upgrade.")
        end
      end
    end)
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
    local width, height = current_geom()
    local proj = M.state.proj or project_m.detect()
    render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active(), height, width)
  end)
  if not ok then alert.error("nav", err) end
end

--- Kembalikan cursor ke baris selected (dipanggil CursorMoved).
function M._snap()
  local st = M.state
  if not st.open or not st.sel_line then return end
  if not (st.win and vim.api.nvim_win_is_valid(st.win)) then return end
  if vim.api.nvim_get_current_win() ~= st.win then return end
  local ok, cur = pcall(vim.api.nvim_win_get_cursor, st.win)
  if ok and cur and cur[1] ~= st.sel_line then
    pcall(vim.api.nvim_win_set_cursor, st.win, { st.sel_line, 2 })
  end
end

function M.top()
  local ok, err = pcall(function()
    M.state.selected = first_selectable(M.state.items)
    local width, height = current_geom()
    local proj = M.state.proj or project_m.detect()
    render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active(), height, width)
  end)
  if not ok then alert.error("top", err) end
end

function M.bottom()
  local ok, err = pcall(function()
    local last = 1
    for i, it in ipairs(M.state.items) do
      if is_selectable(it) then last = i end
    end
    M.state.selected = last
    local width, height = current_geom()
    local proj = M.state.proj or project_m.detect()
    render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active(), height, width)
  end)
  if not ok then alert.error("bottom", err) end
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

function M.do_test()
  local proj = project_m.detect()
  if not ensure_project(proj) then return end
  M.close()
  tasks_m.run(proj, "test")
end

function M.do_custom(cmd, label)
  M.close()
  tasks_m.run_custom(cmd, label)
end

function M.do_rerun()
  if tasks_m.rerun and tasks_m.rerun() then
    M.close()
  end
end

function M.do_cancel_task()
  if tasks_m and tasks_m.stop then
    tasks_m.stop()
    alert.info("Task cancelled")
  end
end

function M.do_emulator()
  M.close()
  local ok, emu = pcall(require, "anvim.emulator")
  if ok then emu.pick_and_launch() end
end

function M.do_scrcpy()
  local ok, scr = pcall(require, "anvim.scrcpy")
  if ok then scr.pick() end
end

function M.do_emulator_kill()
  local ok, emu = pcall(require, "anvim.emulator")
  if ok then emu.pick_and_kill() end
  -- refresh agar status kill terlihat
  if M.state.open then
    refresh_state()
    local width, height = current_geom()
    render(M.state.buf, M.state.items, M.state.selected, M.state.proj, devices_m.get_active(), height, width)
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
      elseif item.task == "emulator" then M.do_emulator()
      elseif item.task == "emulator_kill" then M.do_emulator_kill()
      elseif item.task == "scrcpy" then M.do_scrcpy()
      elseif item.task == "devices" then
        local dl = devices_m.list()
        refresh_state()
        local width, height = current_geom()
        render(M.state.buf, M.state.items, M.state.selected, M.state.proj, devices_m.get_active(), height, width)
        alert.info("Found " .. #dl .. " device(s) — list refreshed")
      else
        local proj = M.state.proj or project_m.detect()
        if not ensure_project(proj) then return end
        M.close()
        tasks_m.run(proj, item.task)
      end
    elseif item.type == "custom" then
      M.close()
      tasks_m.run_custom(item.cmd, item.label)
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
      local width, height = current_geom()
      render(M.state.buf, M.state.items, M.state.selected, M.state.proj, devices_m.get_active(), height, width)
    elseif item.type == "avd" then
      local a = item.avd
      if a.running_id then
        devices_m.set_active(a.running_id)
        alert.info("Active: " .. a.name .. " (" .. a.running_id .. ")")
        refresh_state()
        local width2, height2 = current_geom()
        render(M.state.buf, M.state.items, M.state.selected, M.state.proj, devices_m.get_active(), height2, width2)
      else
        M.close()
        local ok2, emu = pcall(require, "anvim.emulator")
        if ok2 then emu.launch(a.name, { cold_boot = true }) end
      end
    elseif item.type == "scrcpy" then
      local s = item.scrcpy
      local ok2, scr = pcall(require, "anvim.scrcpy")
      if ok2 then
        if s.running then
          scr.stop(s.id)
        else
          scr.launch(s.id, {})
        end
        refresh_state()
        local width3, height3 = current_geom()
        render(M.state.buf, M.state.items, M.state.selected, M.state.proj, devices_m.get_active(), height3, width3)
      end
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
  M.state.sel_line = nil
  pcall(vim.api.nvim_clear_autocmds, { group = "AnvimDashboard" })
  pcall(vim.api.nvim_del_augroup_by_name, "AnvimDashboard")
end

return M
