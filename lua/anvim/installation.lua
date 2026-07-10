-- anvim: installation — download, extract, deploy tools
local M = {}
M.install_active = false
M.install_cancelled = false
M.phase = ""

local alert = require("anvim.status-alert")

-- OS detection (self-contained)
local OS = vim.loop.os_uname().sysname:lower()
if OS:find("windows") or OS:find("win32") then OS = "windows"
elseif OS:find("darwin") then OS = "macos"
else OS = "linux" end

-- helpers
local function fmt_size(bytes)
  if bytes < 1024 then return string.format("%.0f B", bytes) end
  if bytes < 1024*1024 then return string.format("%.1f KB", bytes/1024) end
  if bytes < 1024*1024*1024 then return string.format("%.1f MB", bytes/(1024*1024)) end
  return string.format("%.2f GB", bytes/(1024*1024*1024))
end

local function fmt_time(secs)
  if secs <= 0 then return "--:--:--" end
  local h = math.floor(secs/3600)
  local m = math.floor((secs%3600)/60)
  local s = math.floor(secs%60)
  return string.format("%02d:%02d:%02d", h, m, s)
end

local function fmt_speed(bps)
  if bps < 1024 then return string.format("%.0f B/s", bps) end
  if bps < 1024*1024 then return string.format("%.1f KB/s", bps/1024) end
  return string.format("%.1f MB/s", bps/(1024*1024))
end

local BAR_W = 30

local function render_progress(buf, phase, pct, speed, eta, logs)
  pct = math.min(100, math.max(0, pct))
  local filled = math.floor(pct/100 * BAR_W)
  local empty = BAR_W - filled
  local bar = "[" .. string.rep("■", filled) .. string.rep("□", empty) .. "]"
  local lines = {
    "",
    "  " .. phase,
    "",
    "  " .. bar .. "  " .. string.format("%5.1f%%", pct),
    "  Speed: " .. fmt_speed(speed) .. "    ETA: " .. fmt_time(eta),
    "",
  }
  local start = math.max(1, #logs - 20 + 1)
  for i = start, #logs do
    table.insert(lines, "  > " .. logs[i])
  end
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

local function get_total_size(url)
  if vim.fn.executable("curl") ~= 1 then return 0 end
  local ok, out = pcall(vim.fn.system, "curl -sIkL " .. vim.fn.shellescape(url) .. " 2>/dev/null")
  if not ok then return 0 end
  local len = out:match("[Cc]ontent-[Ll]ength:%s*(%d+)")
  return tonumber(len) or 0
end

local function open_progress_win(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = 60, height = 18,
    col = math.floor((vim.o.columns - 60) / 2),
    row = math.floor((vim.o.lines - 18) / 2),
    style = "minimal", border = "rounded",
    title = " Install " .. name .. " ", title_pos = "center",
  })
  return buf
end

-- install_tool: download → extract → mv to /usr/bin/ → verify
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
  local total = get_total_size(dl_info.url)
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
    render_progress(pw_buf, M.phase, 0, 0, 0, logs)
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
    local pct = total > 0 and (downloaded / total * 100) or 0
    local eta = speed > 0 and total > 0 and ((total - downloaded) / speed) or 0
    render_progress(pw_buf, M.phase, pct, speed, eta, logs)
  end))

  local function close_pw()
    stop_timer()
    M.install_active = false
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
    redraw(); vim.wait(2000); close_pw()
    if on_done then on_done(false) end
    return
  end

  table.insert(logs, "Downloading...")
  redraw()

  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if not M.install_active then return end

      if code ~= 0 then
        table.insert(logs, "Download failed (exit " .. code .. ")")
        redraw(); vim.wait(2000); close_pw()
        if on_done then on_done(false) end
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

        vim.fn.jobstart(extract_cmd, {
          on_exit = function(_, ecode)
            if not M.install_active then return end

            if ecode ~= 0 then
              table.insert(logs, "Extract failed (exit " .. ecode .. ")")
              redraw(); vim.wait(2000); close_pw()
              if on_done then on_done(false) end
              return
            end

            table.insert(logs, "Extract OK")
            table.insert(logs, "Organizing files...")

            local found = vim.fn.glob(extract_dir .. "/**/" .. bin_name, false, true)
            local rel_path = ""
            if #found > 0 then
              local parent = vim.fn.fnamemodify(found[1], ":h")
              rel_path = parent:sub(#extract_dir + 2)
            end

            -- cp → dest, clean zip+extracted
            if OS == "windows" then
              vim.fn.system("move " .. extract_dir .. "\\* " .. dest .. "\\")
            else
              vim.fn.system("cp -r " .. extract_dir .. "/* " .. dest .. "/")
            end
            pcall(os.remove, zip_path)
            pcall(function() vim.fn.system("rm -rf " .. extract_dir) end)
            table.insert(logs, "Installed at: " .. dest)

            -- mv binary ke /usr/bin/
            if OS ~= "windows" then
              local bin_path = dest .. "/" .. rel_path .. "/" .. bin_name
              local target = "/usr/bin/" .. bin_name
              table.insert(logs, "Moving " .. bin_name .. " to " .. target .. " ...")

              local _, me = pcall(vim.fn.system, "mv " .. bin_path .. " " .. target .. " 2>/dev/null; echo __X__:$?")
              if not (me and me:match("__X__:0")) then
                vim.fn.system("sudo mv " .. bin_path .. " " .. target .. " 2>/dev/null")
              end

              if vim.fn.executable(bin_name) == 1 then
                table.insert(logs, "✓ " .. bin_name .. " at /usr/bin/")
              else
                table.insert(logs, "⚠ Failed mv to " .. target .. ", manual:")
                table.insert(logs, "  sudo mv " .. bin_path .. " " .. target)
              end
            end
            redraw()

            -- PHASE 3: verify
            if M.install_active then
              M.phase = "Verifying..."
              table.insert(logs, "Verifying install...")
              redraw()

              local paths = { dest }
              if rel_path and rel_path ~= "" then
                table.insert(paths, dest .. "/" .. rel_path)
              end
              for _, p in ipairs(paths) do
                if not vim.env.PATH:find(p, 1, true) then
                  vim.env.PATH = p .. ":" .. vim.env.PATH
                end
              end

              local exe_name = (OS == "windows") and (name .. ".exe") or name
              if vim.fn.executable(exe_name) == 1 then
                table.insert(logs, "✓ " .. label .. " ready!")
              else
                table.insert(logs, "⚠ Installed but PATH needs manual setup")
              end
              redraw()

              M.phase = "✓ Install done!"
              table.insert(logs, "Press ESC to close")
              stop_timer()
              render_progress(pw_buf, M.phase, 100, 0, 0, logs)
              M.install_active = false
              vim.wait(1500)
              close_pw()
              if on_done then on_done(true) end
            end
          end,
        })
      end
    end,
  })
end

return M
