-- anvim: logcat viewer — live adb logcat, reopen with history, reopen dashboard on close

local M = {}
M.buf = nil
M.win = nil
M.job_id = nil
M.running = false
M.history = {}  -- preserve logs across reopen
M.filter = "I"

local alert = require("anvim.status-alert")

local levels = {
  V = "VERBOSE", D = "DEBUG", I = "INFO",
  W = "WARN", E = "ERROR", F = "FATAL",
}

local function start_logcat(buf, filter)
  if vim.fn.executable("adb") == 0 then
    M.running = false
    return
  end
  local cmd = { "adb", "logcat", "-v", "time", "-s", levels[filter] or "I", "*:" .. (filter or "I") }

  M.job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      if not M.running then return end
      if not data then return end
      local valid_buf = buf and vim.api.nvim_buf_is_valid(buf)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(M.history, line)
          if valid_buf then
            pcall(vim.api.nvim_buf_set_option, buf, "modifiable", true)
            local last = vim.api.nvim_buf_line_count(buf)
            vim.api.nvim_buf_set_lines(buf, last, last, false, { line })
            local max = vim.g.anvim_logcat_max or 5000
            local count = vim.api.nvim_buf_line_count(buf)
            if count > max + 100 then
              vim.api.nvim_buf_set_lines(buf, 0, count - max, false, {})
            end
            pcall(vim.api.nvim_buf_set_option, buf, "modifiable", false)
          end
        end
      end
    end,
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
end

local function setup_keymaps(buf)
  vim.keymap.set("n", "q", function()
    M.stop()
    M.close_win()
  end, { buffer = buf, nowait = true, silent = true, desc = "Close logcat" })
  vim.keymap.set("n", "<Esc>", function()
    M.stop()
    M.close_win()
  end, { buffer = buf, nowait = true, silent = true, desc = "Close logcat" })
  for k, _ in pairs(levels) do
    vim.keymap.set("n", k, function() M.restart(k) end,
      { buffer = buf, nowait = true, silent = true, desc = "Filter " .. levels[k] })
  end
  vim.keymap.set("n", "/", "/", { buffer = buf, nowait = true, silent = false })
end

function M.open(filter)
  local ok, err = pcall(function()
    if vim.fn.executable("adb") == 0 then
      alert.warn("Logcat needs ADB.\nRun :AnvimCheck to install.")
      return
    end

    filter = filter or "I"
    M.filter = filter

    if M.running then
      -- bring existing window front
      if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_set_current_win(M.win)
      end
      return
    end

    local buf = M.buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      buf = vim.api.nvim_create_buf(false, true)
      M.buf = buf
      vim.api.nvim_buf_set_name(buf, "anvim://logcat")
      vim.bo[buf].bufhidden = "hide"
      vim.bo[buf].filetype = "logcat"

      -- restore history
      if #M.history > 0 then
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.history)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
      end
    end

    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", width = math.floor(vim.o.columns * 0.9),
      height = math.floor(vim.o.lines * 0.7), col = math.floor(vim.o.columns * 0.05),
      row = math.floor(vim.o.lines * 0.1), style = "minimal", border = "rounded",
    })
    M.win = win
    vim.api.nvim_win_set_option(win, "wrap", false)

    setup_keymaps(buf)
    M.running = true
    start_logcat(buf, filter)
    alert.info("Logcat | V/D/I/W/E/F filter, / search, q quit")
  end)
  if not ok then alert.error("logcat", err) end
end

function M.restart(filter)
  M.stop()
  -- keep buf alive with history
  M.open(filter)
end

function M.stop()
  M.running = false
  if M.job_id then
    pcall(vim.fn.jobstop, M.job_id)
    M.job_id = nil
  end
end

function M.close_win()
  -- close window, keep buf (hidden) + history, reopen dashboard
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  vim.schedule(function()
    pcall(require("anvim.dashboard").open)
  end)
end

return M
