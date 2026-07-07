-- anvim: TUI dashboard
-- ponytail: floating window with list navigation, no UI framework

local M = {}
M.state = { open = false, selected = 0, items = {} }

local config_m, health_m, project_m, devices_m, tasks_m

local function modules()
  config_m = require "anvim.config"
  health_m = require "anvim.health"
  project_m = require "anvim.project"
  devices_m = require "anvim.devices"
  tasks_m = require "anvim.tasks"
end

-- ponytail: flat item list, no OOP task objects
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

local function render(buf, items, selected, proj, dev_active)
  local lines = {}
  local highlights = {}

  local function add(line, hl)
    table.insert(lines, line)
    table.insert(highlights, { line = #lines, hl = hl })
  end

  -- Title bar
  local title = string.format(" anvim Dashboard  v%s ", "0.1.0")
  local info = string.format(" %s (%s) | Device: %s ",
      proj.name, proj.type, dev_active or "none")

  add("", nil)
  add(title .. string.rep(" ", math.max(0, 50 - #title)) .. info, "Title")
  add(string.rep("─", 60), "NonText")

  local idx = 0
  for _, item in ipairs(items) do
    idx = idx + 1
    local selected = idx == selected and true or false
    local prefix = selected and " →" or "  "

    if item.type == "header" then
      add("", nil)
      add(item.text, "Type")
    elseif item.type == "separator" then
      add("  " .. item.text, "NonText")
    elseif item.type == "task" then
      local hl = selected and "MoreMsg" or "Normal"
      add(prefix .. " " .. (item.icon or " ") .. " " .. item.label, hl)
    elseif item.type == "device" then
      local hl = selected and "MoreMsg" or "Normal"
      add(prefix .. " " .. item.label, hl)
    elseif item.type == "health" then
      local icon = item.result.found and "✓" or "✗"
      local hl = item.result.found and "String" or "Error"
      if selected then hl = "MoreMsg" end
      add(prefix .. string.format(" %s %s", icon, health_m.format_line(item.tool, item.result)), hl)
    end
  end

  -- Footer
  add("", nil)
  add(string.rep("─", 60), "NonText")
  add(" (j/k) Navigate  (Enter) Select  (q) Quit  (c) Check System  (r) Run App  (l) Logcat", "Comment")

  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

function M.open()
  modules()

  if M.state.open then
    vim.notify("[anvim] Dashboard already open", vim.log.levels.INFO)
    return
  end

  local cfg = config_m.get().dashboard
  local width = math.floor(vim.o.columns * cfg.width)
  local height = math.floor(vim.o.lines * cfg.height)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = cfg.border,
  })

  -- ponytail: one-shot cleanup, no autocmd group
  vim.api.nvim_buf_set_name(buf, "anvim://dashboard")

  M.state.open = true
  M.state.buf = buf
  M.state.win = win
  M.state.selected = 1

  local proj = project_m.detect()
  local dev_list = devices_m.list()
  local h_results = health_m.check_configured(config_m.get().health_check.tools)

  M.state.items = build_items(proj, h_results, dev_list)

  render(buf, M.state.items, M.state.selected, proj, devices_m.get_active())

  -- Buffer-local keymaps
  local map_opts = { nowait = true, silent = true, buffer = buf }
  vim.api.nvim_buf_set_keymap(buf, "n", "j", "", vim.tbl_extend("force", map_opts, {
    callback = function() M.nav(1) end, desc = "Next" }))
  vim.api.nvim_buf_set_keymap(buf, "n", "k", "", vim.tbl_extend("force", map_opts, {
    callback = function() M.nav(-1) end, desc = "Previous" }))
  vim.api.nvim_buf_set_keymap(buf, "n", "<Down>", "", vim.tbl_extend("force", map_opts, {
    callback = function() M.nav(1) end, desc = "Next" }))
  vim.api.nvim_buf_set_keymap(buf, "n", "<Up>", "", vim.tbl_extend("force", map_opts, {
    callback = function() M.nav(-1) end, desc = "Previous" }))
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", vim.tbl_extend("force", map_opts, {
    callback = function() M.select() end, desc = "Select" }))
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", vim.tbl_extend("force", map_opts, {
    callback = function() M.close() end, desc = "Close" }))
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", vim.tbl_extend("force", map_opts, {
    callback = function() M.close() end, desc = "Close" }))

  -- Also store proj for use in select()
  M.state.proj = proj
end

function M.nav(dir)
  local total = #M.state.items
  M.state.selected = M.state.selected + dir
  if M.state.selected < 1 then M.state.selected = total end
  if M.state.selected > total then M.state.selected = 1 end

  local proj = M.state.proj or project_m.detect()
  render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active())
end

function M.select()
  local item = M.state.items[M.state.selected]
  if not item then return end

  if item.type == "task" then
    if item.task == "logcat" then
      M.close()
      require("anvim.logcat").open()
    elseif item.task == "check" then
      modules()
      local h = health_m.check_configured(config_m.get().health_check.tools)
      for name, r in pairs(h.tools) do
        print(health_m.format_line(name, r))
      end
      print(string.format("Summary: %d OK, %d missing", h.summary.ok, h.summary.err))
    elseif item.task == "devices" then
      local dl = devices_m.list()
      vim.notify("[anvim] Found " .. #dl .. " device(s)", vim.log.levels.INFO)
    else
      local proj = M.state.proj or project_m.detect()
      tasks_m.run(proj, item.task)
    end
  elseif item.type == "device" then
    devices_m.set_active(item.device.id)
    vim.notify("[anvim] Active device: " .. item.device.id, vim.log.levels.INFO)
    local proj = M.state.proj or project_m.detect()
    render(M.state.buf, M.state.items, M.state.selected, proj, devices_m.get_active())
  end
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
