# anvim

Android/Flutter Development Dashboard for Neovim.

TUI dashboard inside Neovim — alternative to Android Studio. Inspired by lazygit.

## Features

- **Dashboard** — floating TUI with task list, device management, health status
- **Health Check** — detects ADB, Java, Flutter, Git with clear install hints
- **Task Runner** — run, clean, build APK via `jobstart`
- **Logcat Viewer** — live `adb logcat` in a buffer with level filtering (V/D/I/W/E/F)
- **Device Management** — list ADB devices, select active device
- **Project Detection** — auto-detects Flutter (pubspec.yaml) vs Android (build.gradle)

## Requirements

- Neovim >= 0.9.0
- ADB, Java (for Android), Flutter (for Flutter projects) on PATH

## How to use
Add code in your config file
```lua
{
  "Hpipone/anvim",
  opts = {},
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:Anvim` | Open dashboard |
| `:AnvimCheck` | Run health check |
| `:AnvimLogcat` | Open logcat viewer |

## Keymaps

| Key | Action |
|-----|--------|
| `<leader>ad` | Open dashboard |
| `<leader>al` | Open logcat |

### Dashboard

| Key | Action |
|-----|--------|
| `j`/`k` | Navigate |
| `Enter` | Select task/device |
| `q`/`Esc` | Close |
| `c` | Check system health |

### Logcat

| Key | Action |
|-----|--------|
| `V`/`D`/`I`/`W`/`E`/`F` | Filter by level |
| `/` | Search |
| `q`/`Esc` | Close |

## Configuration

```lua
require("anvim").setup({
  dashboard = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
  health_check = {
    auto = true,
    tools = { "adb", "java", "git" },
  },
  logcat = {
    max_lines = 5000,
    filter_default = "I",
  },
})
```

## License

MIT
