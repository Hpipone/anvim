-- anvim: installation — download, extract, deploy tools
local M = {}
M.install_active = false
M.install_cancelled = false
M.phase = ""

local alert = require("anvim.status-alert")

-- OS detection
local OS = vim.loop.os_uname().sysname:lower()
if OS:find("windows") or OS:find("win32") then OS = "windows"
elseif OS:find("darwin") then OS = "macos"
else OS = "linux" end

-- shell detection for RC injection
local SHELL_RC = (OS == "windows") and nil or (
  (vim.env.SHELL and vim.env.SHELL:match("zsh")) and "~/.zshrc"
  or "~/.bashrc"
)

-- helpers
local function fmt_size(bytes)
  if bytes < 1024 then return string.format("%.0f B", bytes) end
  if bytes < 1024*1024 then return string.format("%.1f KB", bytes/1024) end
  if bytes < 1024*1024*1024 then return string.format("%.1f MB", bytes/(1024*1024)) end
  return string.format("%.2f GB", bytes/(1024*1024*1024))
end

local function fmt_speed(bps)
  if bps < 1024 then return string.format("%.0f B/s", bps) end
  if bps < 1024*1024 then return string.format("%.1f KB/s", bps/1024) end
  return string.format("%.1f MB/s", bps/(1024*1024))
end

local BAR_W = 30

local function render_progress(buf, phase, downloaded, total, speed, logs)
  local lines = { "", "  " .. phase, "" }
  if total > 0 then
    local pct = math.min(100, downloaded / total * 100)
    local filled = math.floor(pct/100 * BAR_W)
    local bar = "[" .. string.rep("■", filled) .. string.rep("□", BAR_W-filled) .. "]"
    local eta = speed > 0 and ((total - downloaded) / speed) or 0
    local eta_s = eta > 0 and string.format("%02d:%02d:%02d", math.floor(eta/3600), math.floor((eta%3600)/60), math.floor(eta%60)) or "--:--:--"
    table.insert(lines, "  " .. bar .. "  " .. string.format("%5.1f%%", pct))
    table.insert(lines, "  Downloaded: " .. fmt_size(downloaded) .. " / " .. fmt_size(total) .. "  Speed: " .. fmt_speed(speed) .. "  ETA: " .. eta_s)
  else
    local spinners = { "|", "/", "-", "\\" }
    local s = spinners[math.floor(vim.loop.now()/200) % 4 + 1] or "|"
    table.insert(lines, "  " .. s .. " Downloading... " .. fmt_size(downloaded))
    table.insert(lines, "  Speed: " .. fmt_speed(speed) .. "    Size: unknown")
  end
  table.insert(lines, "")
  local start = math.max(1, #logs - 20 + 1)
  for i = start, #logs do
    table.insert(lines, "  > " .. logs[i])
  end
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

function M.get_total_size(url)
  if vim.fn.executable("curl") == 1 then
    local ok, out = pcall(vim.fn.system, "curl -sIkL " .. vim.fn.shellescape(url) .. " 2>/dev/null | grep -i content-length | tail -1")
    if ok then
      local len = out:match("(%d+)")
      if len and tonumber(len) > 0 then return tonumber(len) end
    end
  end
  if vim.fn.executable("wget") == 1 then
    local ok, out = pcall(vim.fn.system, "wget --spider --server-response " .. vim.fn.shellescape(url) .. " 2>&1 | grep -i content-length | tail -1")
    if ok then
      local len = out:match("(%d+)")
      if len and tonumber(len) > 0 then return tonumber(len) end
    end
  end
  return 0
end

local function open_progress_win(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = 60, height = 24,
    col = math.floor((vim.o.columns - 60) / 2),
    row = math.floor((vim.o.lines - 24) / 2),
    style = "minimal", border = "rounded",
    title = " Install " .. name .. " ", title_pos = "center",
  })
  return buf
end

--- inject PATH line into shell RC for persistent access outside Neovim
--- returns (ok, log_line)
local function inject_path_to_rc(export_line)
  if OS == "windows" then
    -- setx for windows
    local _, out = pcall(vim.fn.system, "setx PATH \"" .. export_line .. ";%PATH%\" 2>&1")
    if out and (out:match("SUCCESS") or out:match("成功")) then
      return true, "✓ PATH set via setx — terminal baru bisa pake"
    end
    return false, "⚠ setx gagal, tambah PATH manual"
  end

  local rc = SHELL_RC
  if not rc then
    return false, "⚠ shell RC gak dikenal, tambah PATH manual"
  end

  -- escape export_line buat grep
  local escaped = export_line:gsub("[" .. '"\'%%' .. "]", "\\%1")
  local check = vim.fn.system("grep -F " .. vim.fn.shellescape(export_line) .. " " .. rc .. " 2>/dev/null")
  if check and check ~= "" then
    return true, "✓ PATH already in " .. rc
  end

  local append = '\n' .. export_line .. '\n'
  local ok = pcall(function()
    local f = io.open(vim.fn.expand(rc), "a")
    if f then f:write(append); f:close() else error() end
  end)

  if ok then
    pcall(vim.fn.system, "source " .. rc .. " 2>/dev/null || true")
    return true, "✓ PATH added to " .. rc .. " — terminal baru bisa pake"
  end
  return false, "⚠ Gagal nulis ke " .. rc .. ", tambah manual: " .. export_line
end

--- mv binary to /usr/bin/, fallback sudo, fallback PATH injection
--- returns (success, log_lines)
function M.deploy_binary(bin_path, bin_name, tool_subdir, logs)
  local lines = {}
  if OS == "windows" then
    -- Windows: binary stays in dest, setx PATH
    return false, lines
  end

  local target = "/usr/bin/" .. bin_name
  table.insert(lines, "Deploy " .. bin_name .. " ...")

  -- ATTEMPT 1: plain mv
  local _, code = pcall(vim.fn.system, "mv " .. bin_path .. " " .. target .. " 2>/dev/null; echo __X__:$?")
  local ok = code and code:match("__X__:0")

  -- ATTEMPT 2: sudo mv
  if not ok then
    table.insert(lines, "  mv perlu sudo...")
    local _, code2 = pcall(vim.fn.system, "sudo mv " .. bin_path .. " " .. target .. " 2>/dev/null; echo __X__:$?")
    ok = code2 and code2:match("__X__:0")
  end

  if ok and vim.fn.executable(bin_name) == 1 then
    table.insert(lines, "✓ " .. bin_name .. " at /usr/bin/")
    return true, lines
  end

  -- ATTEMPT 3: PATH injection ke shell RC
  table.insert(lines, "  mv ke /usr/bin/ gagal (no sudo)")
  table.insert(lines, "  Fallback: persistent PATH...")

  local export_line = 'export PATH="$PATH:' .. tool_subdir .. '"'
  local injected, log_line = inject_path_to_rc(export_line)
  table.insert(lines, "  " .. log_line)

  -- update vim.env.PATH biar session ini bisa
  if not vim.env.PATH:find(tool_subdir, 1, true) then
    vim.env.PATH = tool_subdir .. ":" .. vim.env.PATH
  end

  if vim.fn.executable(bin_name) == 1 then
    table.insert(lines, "✓ " .. bin_name .. " ready (via PATH)")
    return true, lines
  end

  table.insert(lines, "⚠ " .. bin_name .. " not in PATH, manual:")
  table.insert(lines, "  echo '" .. export_line .. "' >> ~/.bashrc")
  return false, lines
end

-- install_tool: download → extract → deploy → verify
function M.install_tool(name, dl_info, label, bin_name, on_done)
  local homedir = vim.fn.expand("~")
  local dest = homedir .. "/.anvim/tools/" .. name
  local zip_path = dest .. "/" .. dl_info.file

  if vim.fn.executable(bin_name) == 1 then
    alert.info(label .. " already in PATH, skip")
    if on_done then on_done(true) end
    return
  end

  vim.fn.mkdir(dest, "p")
  local total = M.get_total_size(dl_info.url)
  local logs = {}
  local start_time = vim.loop.now()
  M.install_active = true
  M.phase = "Starting " .. label .. "..."

  local pw_buf = open_progress_win(label)
  require("anvim.keymaps.installation").set(pw_buf)

  local last_bytes = 0
  local last_time = start_time
  local speed = 0
  local timer

  local function stop_timer()
    if timer then timer:stop(); timer = nil end
  end

  local function redraw()
    local info = vim.loop.fs_stat(zip_path)
    local dl = info and info.size or 0
    render_progress(pw_buf, M.phase, dl, total, speed, logs)
  end

  timer = vim.loop.new_timer()
  timer:start(0, 200, vim.schedule_wrap(function()
    if not M.install_active then stop_timer(); return end
    local info = vim.loop.fs_stat(zip_path)
    local downloaded = info and info.size or 0
    local now = vim.loop.now()
    local dt = (now - last_time) / 1000
    if dt > 0 then
      speed = (speed * 0.7) + ((downloaded - last_bytes) / dt * 0.3)
    end
    last_bytes = downloaded
    last_time = now
    render_progress(pw_buf, M.phase, downloaded, total, speed, logs)
  end))

  local function close_pw()
    stop_timer()
    M.install_active = false
    M.job_id = nil
    if pw_buf and vim.api.nvim_buf_is_valid(pw_buf) then
      vim.api.nvim_buf_delete(pw_buf, { force = true })
    end
  end

  -- PHASE 1: download
  M.phase = "Downloading " .. label .. "..."
  local cmd
  if vim.fn.executable("curl") == 1 then
    cmd = { "curl", "-L", "-o", zip_path, dl_info.url }
  elseif vim.fn.executable("wget") == 1 then
    cmd = { "wget", "-O", zip_path, dl_info.url }
  else
    table.insert(logs, "ERROR: need curl or wget")
    redraw()
    stop_timer()
    vim.defer_fn(function() close_pw(); if on_done then on_done(false) end end, 2000)
    return
  end

  table.insert(logs, "Downloading...")
  redraw()

  M.job_id = vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if not M.install_active then return end

      if code ~= 0 then
        table.insert(logs, "Download failed (exit " .. code .. ")")
        redraw()
        stop_timer()
        vim.defer_fn(function() close_pw(); if on_done then on_done(false) end end, 2000)
        return
      end

      table.insert(logs, "Download done (" .. fmt_size(total) .. ")")
      redraw()

      -- PHASE 2: extract
      if M.install_active then
        M.phase = "Extracting " .. label .. "..."
        table.insert(logs, "Extracting...")
        redraw()

        local extract_cmd
        local extract_dir = dest .. "/extracted"
        vim.fn.mkdir(extract_dir, "p")

        if zip_path:match("%.zip$") then
          if vim.fn.executable("unzip") == 1 then
            extract_cmd = { "unzip", "-o", zip_path, "-d", extract_dir }
          end
        elseif zip_path:match("%.tar%.xz$") or zip_path:match("%.tar%.gz$") or zip_path:match("%.tgz$") then
          if vim.fn.executable("tar") == 1 then
            extract_cmd = { "tar", "-xf", zip_path, "-C", extract_dir }
          end
        end

        if not extract_cmd then
          table.insert(logs, "Manual extract: " .. zip_path)
          redraw(); close_pw()
          if on_done then on_done(false) end
          return
        end

        table.insert(logs, "Running: " .. table.concat(extract_cmd, " "))
        redraw()

        M.job_id = vim.fn.jobstart(extract_cmd, {
          on_exit = function(_, ecode)
            if not M.install_active then return end

            if ecode ~= 0 then
              table.insert(logs, "Extract failed (exit " .. ecode .. ")")
              redraw()
              stop_timer()
              vim.defer_fn(function() close_pw(); if on_done then on_done(false) end end, 2000)
              return
            end

            table.insert(logs, "Extract OK")
            table.insert(logs, "Organizing files...")

            -- find binary inside extracted dir
            local found = vim.fn.glob(extract_dir .. "/**/" .. bin_name, false, true)
            local rel_path = ""
            if #found > 0 then
              local parent = vim.fn.fnamemodify(found[1], ":h")
              rel_path = parent:sub(#extract_dir + 2)
            end

            -- cp all → dest, clean up zip+extract
            if OS == "windows" then
              vim.fn.system("move " .. extract_dir .. "\\* " .. dest .. "\\")
            else
              vim.fn.system("cp -r " .. extract_dir .. "/* " .. dest .. "/")
            end
            pcall(os.remove, zip_path)
            pcall(function() vim.fn.system("rm -rf " .. extract_dir) end)
            table.insert(logs, "Installed at: " .. dest)
            redraw()

            -- PHASE 3: deploy (mv /usr/bin/ → sudo → PATH injection)
            M.phase = "Deploying " .. label .. "..."
            local tool_subdir = dest
            if rel_path and rel_path ~= "" then
              tool_subdir = dest .. "/" .. rel_path
            end

            local bin_path = tool_subdir .. "/" .. bin_name
            local deployed, deploy_logs = M.deploy_binary(bin_path, bin_name, tool_subdir, logs)
            for _, l in ipairs(deploy_logs) do
              table.insert(logs, l)
            end
            redraw()

            -- PHASE 4: verify
            M.phase = "Verifying..."
            table.insert(logs, "Verifying...")
            redraw()

            -- update vim.env.PATH
            local paths = { "/usr/bin", dest }
            if rel_path and rel_path ~= "" then
              table.insert(paths, dest .. "/" .. rel_path)
            end
            for _, p in ipairs(paths) do
              if not vim.env.PATH:find(p, 1, true) then
                vim.env.PATH = p .. ":" .. vim.env.PATH
              end
            end

            if vim.fn.executable(bin_name) == 1 then
              table.insert(logs, "✓ " .. label .. " siap dipakai!")
            else
              table.insert(logs, "⚠ " .. label .. " belum di PATH")
            end
            redraw()

            M.phase = "✓ Install done!"
            table.insert(logs, "Press ESC to close")
            stop_timer()
            render_progress(pw_buf, M.phase, total, total, 0, logs)
            M.install_active = false
            vim.defer_fn(function() close_pw(); if on_done then on_done(true) end end, 1500)
          end,
        })
      end
    end,
  })
end

return M
