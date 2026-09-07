# anvim long-term plan

> Hasil grilling R1–R3. Fase 1 = refaktor v0.3.0 (sudah dieksekusi).
> Fase 2+ dikerjakan setelah Fase 1 stabil agar banyak user bisa pakai.

## Fase 1 — Refaktor v0.3.0 (DONE)
- [x] `util.lua` single-source (OS/ARCH/shellescape/clamp/float_geom/project_root)
- [x] `health.lua` jadi shim → `system_check.lua` single-source + version
- [x] `config` single-source (dashboard/logcat/tasks/install) + `init` leader fix
- [x] Install no-sudo `~/.local/bin` + shellescape + strict sha256 + timer close + cancel fix
- [x] Dashboard clamp + skip header + rebuild + rounded dari config (v0.3.0)
- [x] Devices multi-device `-s` + unauthorized/offline + model dash/dot + full id
- [x] Tasks timeout + git-root cwd + split+quickfix + `-s/-d` + stop()
- [x] Logcat `*:LEVEL` benar + `schedule_wrap` + trim history + `no_dashboard_on_close`
- [x] Tests 58 pass (11 suites) + docs v0.3.0

## Fase 2 — Emulator manager (NEXT)
- [ ] `adb emu` / `emulator -list-avds` listing (nama AVD, bukan cuma emulator-5554)
- [ ] Launch emulator (`-avd`, cold-boot flag, snapshot) dari dashboard
- [ ] Kill/restart emulator, wipe-data opsional
- [ ] Auto-select emulator yang baru boot sebagai active device
- [ ] Tests: parse `emulator -list-avds`, boot timeout

## Fase 3 — Developer experience
- [ ] LSP integration: tampilkan diagnostics count di dashboard
- [ ] Test integration: `flutter test` / `./gradlew test` sebagai task + quickfix parse
- [ ] Theming: highlight groups (`AnvimSelected`, `AnvimHeader`, `AnvimOk/Err`) + colorscheme respect
- [ ] Extension API: `setup({tasks={custom={{label,cmd}}}})` + command `:AnvimCustom`
- [ ] Health advanced: minimum version check (Java 17+, Gradle 8+, ADB 34+)

## Fase 4 — Hardening & distribusi
- [ ] CI headless (`nvim --headless -l tests/run.lua`) + luacheck/stylua
- [ ] Update checksum map per rilis Flutter/Gradle (otomatis via script)
- [ ] README demo (asciinema/gif), doc tags (`:helptags`)
- [ ] Release v1.0.0 saat Fase 2–3 stabil di Linux/macOS/Windows
