-- anvim: TUI dashboard
-- ponytail: floating window with list navigation, no UI framework

local M = {}
M.state = { open = false, selected = 0, items = {} }

local config_m, health_m, project_m, devices_m, tasks_m

local function modules()
  local ok, err
  ok, config_m = pcall(require, "anvim.config")
  if not ok then vim.notify("[anvim] ERROR dashboard: config — " .. tostring(config_m), vim.log.levels.ERROR) end
  ok, health_m = pcall(require, "anvim.health")
  if not ok then vim.notify("[anvim] ERROR dashboard: health — " .. tostring(health_m), vim.log.levels.ERROR) end
  ok, project_m = pcall(require, "anvim.project")
  if not ok then vim.notify("[anvim] ERROR dashboard: project — " .. tostring(project_m), vim.log.levels.ERROR) end
  ok, devices_m = pcall(require, "anvim.devices")
  if not ok then vim.notify("[anvim] ERROR dashboard: devices — " .. tostring(devices_m), vim.log.levels.ERROR) end
  ok, tasks_m = pcall(require, "anvim.tasks")
  if not ok then vim.notify("[anvim] ERROR dashboard: tasks — " .. tostring(tasks_m), vim.log.levels.ERROR) end
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
  local ok, err = pcall(function()
    local lines = {}
    local highlights = {}

    local function add(line, hl)
      table.insert(lines, line)
      table.insert(highlights, { line = #lines, hl = hl })
    end

    local title = string.format(" anvim Dashboard  v%s ", "0.1.0")
    local info = string.format(" %s (%s) | Device: %s ", proj.name, proj.type, dev_active or "none")

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
        add(prefix .. " " .. (item.icon or " ") .. " " .. item.label, selected and "MoreMsg" or "Normal")
      elseif item.type == "device" then
        add(prefix .. " " .. item.label, selected and "MoreMsg" or "Normal")
      elseif item.type == "health" then
        local icon = item.result.found and "✓" or "✗"
        add(prefix .. string.format(" %s %s", icon, health_m.format_line(item.tool, item.result)), selected and "MoreMsg" or (item.result.found and "String" or "Error"))
      end
    end

    add("", nil)
    add(string.rep("─", 60), "NonText")
    add(" j/k Navigate  Enter Select  q Quit  c Check  r Run  l Logcat", "Comment")

    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
  end)
  if not ok then
    vim.notify("[anvim] ERROR render: " .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.open()
  local ok, err = pcall(function()
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
      relative = "editor", width = width, height = height,
      col = col, row = row, style = "minimal", border = cfg.border,
    })

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

    -- ponytail: <Cmd> lebih reliable daripada Lua callback di floating window
    vim.api.nvim_buf_set_keymap(buf, "n", "j", "<Cmd>lua require('anvim.dashboard').nav(1)<CR>", { nowait = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "k", "<Cmd>lua require('anvim.dashboard').nav(-1)<CR>", { nowait = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Down>", "<Cmd>lua require('anvim.dashboard').nav(1)<CR>", { nowait = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Up>", "<Cmd>lua require('anvim.dashboard').nav(-1)<CR>", { nowait = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('anvim.dashboard').select()<CR>", { nowait = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>lua require('anvim.dashboard').close()<CR>", { nowait = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>lua require('anvim.dashboard').close()<CR>", { nowait = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "c", "<Cmd>AnvimCheck<CR>", { nowait = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "r", "<Cmd>q<CR><Cmd>AnvimRun<CR>", { nowait = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "l", "<Cmd>AnvimLogcat<CR>", { nowait = true, silent = true })

    M.state.proj = proj
  end)
  if not ok then
    vim.notify("[anvim] ERROR buka dashboard: " .. tostring(err), vim.log.levels.ERROR)
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
  if not ok then vim.notify("[anvim] ERROR nav: " .. tostring(err), vim.log.levels.ERROR) end
end

function M.select()
  local ok, err = pcall(function()
    local item = M.state.items[M.state.selected]
    if not item then return end
    if item.type == "task" then
      if item.task == "logcat" then
        M.close()
        require("anvim.logcat").open()
      elseif item.task == "check" then
        M.close()
        require("anvim.help_check").interactive()
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
  end)
  if not ok then vim.notify("[anvim] ERROR select: " .. tostring(err), vim.log.levels.ERROR) end
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
