-- anvim: logcat viewer — live adb logcat, filter level benar, history trim, device -s

local M = {}
M.buf = nil
M.win = nil
M.job_id = nil
M.running = false
M.history = {}
M.filter = "I"
M.tag = nil

local alert = require("anvim.status-alert")

local levels = {
  V = "VERBOSE", D = "DEBUG", I = "INFO",
  W = "WARN", E = "ERROR", F = "FATAL",
}

local function cfg_logcat()
  local ok, c = pcall(function() return require("anvim.config").get() end)
  local l = ok and c and c.logcat or {}
  local max = l.max_lines or vim.g.anvim_logcat_max or 5000
  return { max_lines = max, filter_default = l.filter_default or "I" }
end

local function build_cmd(filter, tag)
  local adb_bin = "adb"
  pcall(function()
    local p = require("anvim.system_check").adb_bin()
    if p and p ~= "" then adb_bin = p end
  end)
  local cmd = { adb_bin }
  local ok, dev = pcall(require, "anvim.devices")
  if ok and dev and dev.get_active then
    local id = dev.get_active()
    if id and id ~= "" then
      vim.list_extend(cmd, { "-s", id })
    end
  end
  vim.list_extend(cmd, { "logcat", "-v", "time" })
  if tag and tag ~= "" then
    vim.list_extend(cmd, { "-s", tag })
  end
  vim.list_extend(cmd, { "*:" .. (filter or "I") })
  return cmd
end

M._build_cmd = build_cmd

local function trim_history()
  local max = cfg_logcat().max_lines
  while #M.history > max do
    table.remove(M.history, 1)
  end
end

local function start_logcat(buf, filter, tag)
  local has_adb = false
  pcall(function() has_adb = require("anvim.system_check").adb_bin() ~= nil end)
  if not has_adb and vim.fn.executable("adb") == 0 then
    M.running = false
    return
  end
  local cmd = build_cmd(filter, tag)

  local job = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    on_stdout = vim.schedule_wrap(function(_, data)
      if not M.running then return end
      if not data then return end
      local new_lines = {}
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(M.history, line)
          table.insert(new_lines, line)
        end
      end
      trim_history()
      if #new_lines > 0 and buf and vim.api.nvim_buf_is_valid(buf) then
        pcall(function()
          vim.bo[buf].modifiable = true
          local last = vim.api.nvim_buf_line_count(buf)
          vim.api.nvim_buf_set_lines(buf, last, last, false, new_lines)
          local max = cfg_logcat().max_lines
          local count = vim.api.nvim_buf_line_count(buf)
          if count > max + 100 then
            vim.api.nvim_buf_set_lines(buf, 0, count - max, false, {})
          end
          vim.bo[buf].modifiable = false
        end)
      end
    end),
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        alert.warn("logcat: " .. table.concat(data, " "))
      end
    end,
    on_exit = function()
      M.running = false
      M.job_id = nil
    end,
  })
  if job == nil or job <= 0 then
    M.running = false
    M.job_id = nil
    alert.error("logcat", "jobstart failed: " .. table.concat(cmd, " "))
    return
  end
  M.job_id = job
end

local function setup_keymaps(buf)
  vim.keymap.set("n", "q", function()
    M.close_win()
  end, { buffer = buf, nowait = true, silent = true, desc = "Close logcat" })
  vim.keymap.set("n", "<Esc>", function()
    M.close_win()
  end, { buffer = buf, nowait = true, silent = true, desc = "Close logcat" })
  for k, _ in pairs(levels) do
    local key = k
    vim.keymap.set("n", key, function() M.restart(key) end,
      { buffer = buf, nowait = true, silent = true, desc = "Filter " .. levels[key] })
  end
  -- "/" native (search). Tambahan: yy copy baris, S simpan ke file.
  vim.keymap.set("n", "yy", function()
    local ok, line = pcall(vim.api.nvim_get_current_line)
    if ok and line then
      vim.fn.setreg("+", line)
      alert.info("Copied line")
    end
  end, { buffer = buf, nowait = true, silent = true, desc = "Copy line" })
  vim.keymap.set("n", "S", function()
    M.save()
  end, { buffer = buf, nowait = true, silent = true, desc = "Save logcat" })
  vim.keymap.set("n", "T", function()
    vim.fn.inputsave()
    local tag = vim.fn.input("Tag filter (empty = reset): ")
    vim.fn.inputrestore()
    M.set_tag(tag)
  end, { buffer = buf, nowait = true, silent = true, desc = "Filter by tag" })
end

function M.open(filter, tag)
  local ok, err = pcall(function()
    local has_adb = false
    pcall(function() has_adb = require("anvim.system_check").adb_bin() ~= nil end)
    if not has_adb and vim.fn.executable("adb") == 0 then
      alert.warn("ADB not found in Neovim PATH.\nLaunch nvim from terminal or run :AnvimCheck.")
      return
    end

    filter = filter or cfg_logcat().filter_default or "I"
    M.filter = filter
    if tag ~= nil then M.tag = (tag ~= "" and tag or nil) end

    if M.running then
      if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_set_current_win(M.win)
        return
      end
      -- job masih hidup tapi window dimatikan paksa → recreate menempel
      -- ke job yang jalan (history utuh), tanpa spawn job baru
      if M.job_id then
        M.win = nil
      else
        M.running = false
      end
    end

    local buf = M.buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      buf = vim.api.nvim_create_buf(false, true)
      M.buf = buf
      pcall(vim.api.nvim_buf_set_name, buf, "anvim://logcat")
      vim.bo[buf].bufhidden = "hide"
      vim.bo[buf].filetype = "logcat"

      if #M.history > 0 then
        trim_history()
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.history)
        vim.bo[buf].modifiable = false
      end
    end

    local cols = vim.o.columns or 80
    local lines_n = vim.o.lines or 24
    local title = " logcat *:" .. M.filter .. (M.tag and (" [" .. M.tag .. "]") or "") .. " "
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", width = math.floor(cols * 0.9),
      height = math.floor(lines_n * 0.7), col = math.floor(cols * 0.05),
      row = math.floor(lines_n * 0.1), style = "minimal", border = "rounded",
      title = title, title_pos = "center",
    })
    M.win = win
    vim.wo[win].wrap = false

    setup_keymaps(buf)
    if M.job_id then
      -- recover: tempel ke job yang masih hidup
      M.running = true
      M.win = win
      vim.wo[win].wrap = false
      alert.info("Logcat reattached (" .. #M.history .. " lines)")
      return
    end
    M.running = true
    start_logcat(buf, filter, M.tag)
    if M.running then
      alert.info("Logcat | V/D/I/W/E/F filter, T tag, S save, yy copy, q quit")
    end
  end)
  if not ok then alert.error("logcat", err) end
end

function M.restart(filter, tag)
  if tag ~= nil then M.tag = (tag ~= "" and tag or nil) end
  M.stop()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    pcall(vim.api.nvim_win_close, M.win, true)
  end
  M.win = nil
  M.open(filter or M.filter, M.tag)
end

--- Filter berdasarkan tag (native adb `-s Tag`). Kosongkan untuk reset.
function M.set_tag(tag)
  M.restart(nil, tag)
end

--- Simpan history ke file. Return path atau nil.
function M.save(path)
  if #M.history == 0 then
    alert.warn("Empty logcat — nothing saved.")
    return nil
  end
  path = path or (vim.fn.expand("~/anvim-logcat-" .. os.date("%Y%m%d-%H%M%S") .. ".log"))
  local ok, err = pcall(vim.fn.writefile, M.history, path)
  if not ok then
    alert.error("logcat save", err)
    return nil
  end
  alert.ok("Logcat saved: " .. path .. " (" .. #M.history .. " lines)")
  return path
end

function M.stop()
  M.running = false
  if M.job_id then
    pcall(vim.fn.jobstop, M.job_id)
    M.job_id = nil
  end
end

function M.close_win()
  -- satu entry point tutup: selalu stop job (anti bocor), buffer+history utuh
  M.stop()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    pcall(vim.api.nvim_win_close, M.win, true)
  end
  M.win = nil
  -- seperti check: keluar → kembali ke dashboard (bukan hilang ke kode)
  vim.schedule(function()
    pcall(require("anvim.dashboard").open)
  end)
end

return M
