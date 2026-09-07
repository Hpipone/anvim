# anvim long-term plan

> Hasil grilling R1–R3. Fase 1 = refaktor v0.3.0 (sudah dieksekusi + commit master).
> Fase 2 = emulator manager (diekseskusi sekarang).

## Fase 1 — Refaktor v0.3.0 (DONE)
- [x] `util.lua` single-source (OS/ARCH/shellescape/clamp/float_geom/project_root)
- [x] `health.lua` jadi shim → `system_check.lua` single-source + version
- [x] `config` single-source (dashboard/logcat/tasks/install) + `init` leader fix
- [x] Install no-sudo `~/.local/bin` + shellescape + sha256 best-effort + timer close + cancel fix
- [x] Dashboard clamp + skip header + rebuild + rounded dari config (v0.3.0)
- [x] Devices multi-device `-s` + unauthorized/offline + model dash/dot + full id
- [x] Tasks timeout + git-root cwd + split+quickfix + `-s/-d` + stop()
- [x] Logcat `*:LEVEL` benar + `schedule_wrap` + trim history + `no_dashboard_on_close`
- [x] Tests 58 pass (11 suites) + docs v0.3.0

## Fase 2 — Emulator manager (DONE)
- [x] `emulator -list-avds` listing + `find_binary` (PATH/ANDROID_HOME/SDK default paths)
- [x] Launch emulator (`-avd`, cold-boot/quick/wipe-data) via dashboard + `:AnvimEmulator` + key `e`
- [x] Kill emulator (`adb -s <id> emu kill`) via dashboard + `:AnvimEmulatorKill`
- [x] Auto-select emulator baru (poll adb 60s) + boot wait `sys.boot_completed` + timeout config
- [x] Dashboard section Emulators (running/stopped) — pilih running = set active, pilih stopped = launch
- [x] Tests: parse, find_binary, build cmd, boot parse, running_map, kill/launch gagal (68 pass total)

## Fase 3 — Developer experience (DONE, v0.4.0)
- [x] System check rombak: UI selectable keyboard-driven (Enter/i/q), version parse + minimum (Java 17, Gradle 8), emulator opsional, URL Flutter 3.47.0 + Gradle 9.7.1 (macOS ARM split)
- [x] LSP integration: diagnostics count (E/W) di dashboard, filter project root
- [x] Test integration: task `test` (`flutter test` / `gradlew test`) + item dashboard + key `t` + `:AnvimTest`
- [x] Theming: `theme.lua` (`AnvimTitle/Header/Selected/Ok/Warn/Error/Hint`) dipakai dashboard + system check
- [x] Extension API: `tasks.custom` + item ★ + `:AnvimCustom` + `tasks.run_custom`
- [x] `health_check.auto`: warning missing/outdated saat dashboard dibuka
- [x] Active device persisten (`~/.anvim/active_device`, restore + clear)
- [x] Tests 84 pass (13 suites)

## Fase 4 — Pre-release upgrade (diusulkan, belum dieksekusi)
- [ ] ANDROID_HOME setup helper: deteksi + tawarkan export ke shell RC + validasi
- [ ] `gradlew` auto `chmod +x` saat terdeteksi tidak executable (dengan konfirmasi)
- [ ] `flutter devices` listing di dashboard (browser/desktop disamping emulator fisik)
- [ ] Logcat simpan ke file (`:AnvimLogcatSave {path}`) + filter tag (`-s TagName`)
- [ ] Task history: rerun last task (`:AnvimRerun`, key `R`) + status spinner di dashboard
- [ ] Statusline/lualine component: `project • device • task…` (modul `anvim.statusline`)
- [ ] Logcat search highlight + copy line ke clipboard (`yy`)
- [ ] Offline docs: `:helptags` check + `:AnvimHelp` + README demo (asciinema/gif)
- [ ] CI headless (`nvim --headless -l tests/run.lua`) + stylua/luacheck + matrix OS
- [ ] Release v1.0.0 saat Fase 2–4 stabil di Linux/macOS/Windows
