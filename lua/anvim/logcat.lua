-- anvim: logcat viewer in a Neovim buffer
-- ponytail: jobstart + live buffering, no external deps

local M = {}
M.buf = nil
M.job_id = nil
M.running = false
M.timer = nil

local levels = {
  V = "VERBOSE",
  D = "DEBUG",
  I = "INFO",
  W = "WARN",
  E = "ERROR",
  F = "FATAL",
}

local function start_logcat(buf, filter)
  if vim.fn.executable("adb") == 0 then
    M.running = false
    return
  end
  local cmd = { "adb", "logcat", "-v", "color", "-s", filter and levels[filter] or "I", "*:" .. (filter or "I") }

  M.job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      if not M.running then return end
      if not data or not vim.api.nvim_buf_is_valid(buf) then
        M.stop()
        return
      end
      pcall(vim.api.nvim_buf_set_option, buf, "modifiable", true)
      local content = {}
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(content, line)
        end
      end
      if #content > 0 then
        local last = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_buf_set_lines(buf, last, last, false, content)
        local max = vim.g.anvim_logcat_max or 5000
        local count = vim.api.nvim_buf_line_count(buf)
        if count > max + 100 then
          vim.api.nvim_buf_set_lines(buf, 0, count - max, false, {})
        end
      end
      pcall(vim.api.nvim_buf_set_option, buf, "modifiable", false)
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        vim.notify("[anvim] logcat stderr: " .. table.concat(data, " "), vim.log.levels.WARN)
      end
    end,
    on_exit = function()
      M.running = false
      M.job_id = nil
    end,
  })
end

function M.open(filter)
  local ok, err = pcall(function()

    -- Cek adb dulu — sebelum buat buffer/win apapun
    if vim.fn.executable("adb") == 0 then
      vim.notify("⚠️ Fitur Logcat butuh ADB (Android Debug Bridge).\nJalankan :AnvimCheck buat cek & install otomatis.", vim.log.levels.WARN)
      return
    end

    if M.running then
      vim.notify("[anvim] Logcat already running in buffer " .. M.buf, vim.log.levels.WARN)
      return
    end

    filter = filter or "I"
    local buf = vim.api.nvim_create_buf(false, true)
    M.buf = buf

    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", width = math.floor(vim.o.columns * 0.9),
      height = math.floor(vim.o.lines * 0.7), col = math.floor(vim.o.columns * 0.05),
      row = math.floor(vim.o.lines * 0.1), style = "minimal", border = "rounded",
    })

    vim.api.nvim_buf_set_name(buf, "anvim://logcat")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "filetype", "logcat")
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_win_set_option(win, "wrap", false)

    vim.keymap.set("n", "q", "<cmd>bdelete!<CR>", { buffer = buf, nowait = true, silent = true, desc = "Close logcat" })
    vim.keymap.set("n", "<Esc>", "<cmd>bdelete!<CR>", { buffer = buf, nowait = true, silent = true, desc = "Close logcat" })
    for k, _ in pairs(levels) do
      local level_key = k
      vim.keymap.set("n", k, function() M.restart(level_key) end,
        { buffer = buf, nowait = true, silent = true, desc = "Filter " .. levels[k] })
    end
    vim.keymap.set("n", "/", "/", { buffer = buf, nowait = true, silent = false, desc = "Search" })

    M.running = true
    start_logcat(buf, filter)
    vim.notify("[anvim] Logcat opened | V/D/I/W/E/F filter, / search, q quit", vim.log.levels.INFO)
  end)
  if not ok then
    vim.notify("[anvim] ERROR buka logcat: " .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.restart(filter)
  M.stop()
  vim.wait(200, function() return not M.running end, 50)
  M.open(filter)
end

function M.stop()
  M.running = false
  if M.job_id then
    pcall(vim.fn.jobstop, M.job_id)
    M.job_id = nil
  end
end

return M
