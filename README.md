# anvim

**Android / Flutter toolkit for Neovim.** Floating TUI dashboard — a lightweight alternative to Android Studio. Think lazygit for mobile dev.

> **v1.6.4** — Stable (honest connect, no record)

## Features

- **Dashboard** — floating window, keyboard-only (`j/k`, no horizontal drift), LSP diagnostics, instant open (never scans on open; shows last check, `c` to scan)
- **Projects** — Flutter, Android/Gradle, **and Node** (`package.json` scripts: `npm run dev/build/test`). No forced installs: run works with whatever runner the project uses. Nearest marker wins in monorepos; force via `setup({project={type="node"}})` or `.anvim.json`
- **System check** — checks only tools relevant to your project type (Node is never nagged about Flutter); detects ADB, Java, Flutter, Git, Gradle (+Emulator, +Scrcpy), enforces minimum versions, one-key auto-install (optional tools offered too)
- **Device sections** — Emulator/Scrcpy appear only when an adb device is connected, hidden otherwise
- **Detection** — canonical `~/.local/bin` first, then PATH, SDK paths, `ANDROID_HOME`, then your folders (`~/Downloads`, `~/Documents`, `detect.extra_dirs`). Deep folder search runs **after** the dashboard opens (or when you trigger `:AnvimCheck`), never blocking it
- **Installer** — download → checksum → extract → symlink into `~/.local/bin`, no sudo, multi-shell PATH; `:AnvimCheck` auto-repairs old installs
- **Tasks** — run / clean / build / test / custom, timeout + cancel, split output + quickfix
- **Logcat** — live view, level/tag filters, save to file, clipboard copy
- **Devices** — multi-device select (`-s` everywhere, `ANDROID_SERIAL` for Gradle), offline/unauthorized warnings, persistent active device
- **Emulator** — list AVDs, launch (cold/quick/wipe), kill, boot wait + auto-select
- **Scrcpy** — show + control phone per device, custom flags; replaces emulator section when installed (install via `:AnvimCheck`)

## Requirements

Neovim >= 0.9. Run `:AnvimCheck` to detect and install the rest.

> adb works in terminal but not in anvim? Your Neovim was likely launched
> without shell PATH (GUI/launcher). Launch nvim from a terminal, or run
> `:AnvimDoctor` to see what Neovim resolves.

## Install (lazy.nvim)

```lua
return { "Hpipone/anvim", opts = {} }
```

<details>
<summary>Full config</summary>

```lua
return {
  "Hpipone/anvim",
  opts = {
    dashboard = { width = 0.8, height = 0.8, border = "rounded" },
    logcat = { max_lines = 5000, filter_default = "I" },
    tasks = {
      timeout_ms = 300000,
      custom = {
        { label = "Lint", cmd = { "flutter", "analyze" } },
      },
    },
    emulator = { boot_timeout_ms = 120000 },
    detect = {
      extra_dirs = { "~/tools" }, -- searched last (depth-limited, cached)
      max_depth = 3,
      cache_ttl = 300,
    },
    scrcpy = {
      replace_emulator = true, -- hide emulator section when scrcpy exists
      max_size = 1920,
      bit_rate = "8M",
      audio = false, -- true = forward audio too
      stay_awake = true,
      turn_screen_off = true,
    },
  },
}
```
</details>

Disable defaults: `vim.g.anvim_no_default_keymaps = true`

## Usage

| Keys (dashboard) | Action |
|---|---|
| `j`/`k`, `gg`/`G` | Move (vertical only) |
| `Enter` | Select |
| `r` / `t` / `R` | Run app / tests / rerun last |
| `l` | Logcat |
| `e` | Emulator |
| `m` | Scrcpy |
| `:` | adb console (toggle: pair+code, connect IP:port, shell, custom) |
| `x` | Cancel task |
| `q` | Quit |

| Command | Action |
|---|---|
| `:Anvim` | Dashboard (`<leader>ad`) |
| `:AnvimCheck` | System check + installer (the only scan; dashboard just displays it) |
| `:AnvimDoctor` | Environment issues (ANDROID_HOME, emulator) |
| `:AnvimRun` / `:AnvimTest` / `:AnvimRerun` / `:AnvimCustom` | Tasks |
| `:AnvimLogcat` (`<leader>al`) / `:AnvimLogcatSave [path]` | Logs |
| `:AnvimEmulator` / `:AnvimEmulatorKill` | Emulator |
| `:AnvimScrcpy` / `:AnvimScrcpyKill` | Show phone screen |
| `:AnvimAdb` | adb console with command toggle |
| `:AnvimTaskClose` | Close task output window (q works too, returns to dashboard) |
| `:AnvimHelp` | Help |

Logcat keys: `V/D/I/W/E/F` level, `T` tag, `S` save, `yy` copy line, `/` search.

Custom tasks appear in the dashboard (★). No line highlights at all — cursor (cursorline) marks selection. Groups: `AnvimTitle/Header/Selected/Ok/Warn/Error/Hint`. Statusline: `require("anvim.statusline").lualine()`.

## Tests

```sh
nvim --headless -l tests/run.lua   # 160 unit tests, no framework
```

## Roadmap

See `todo-plan.md`. PRs welcome.

## License

MIT
