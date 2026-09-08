# Rules для Windows и macOS

Правила provisioning пересмотрены по принципу доверенной разработки:
обычные команды получают `allow`, явно разрушительные действия — `prompt`.
Модели, MCP и текущие значения `approvals_reviewer` в этой правке не меняются.
`allow` разрешает выход за sandbox, поэтому это осознанное доверие инструментам,
а не ограничение всех возможных побочных эффектов.

## Разрешённые задачи

Обе платформы: обычные Git add/commit и просмотр изменений, SSH/SCP/SFTP/rsync,
сборки и тесты, установка утилит, редактирование файлов, GDB/LLDB и анализ бинарников.

macOS дополнительно: Homebrew install/upgrade, компиляторы, Swift/Xcodebuild,
otool/atos/sample/vmmap/leaks, чтение diskutil list/info, sudo make install,
sudo cmake --install и установка подготовленного pkg.

Windows дополнительно: MSVC/MSBuild, cdb/WinDbg/dumpbin, PowerShell cmdlets для
копирования/редактирования, установка модулей, winget/scoop/choco.
Поддержаны также явные имена `ssh.exe`, `gdb.exe` и других основных инструментов.

`wsl` и `wsl.exe` разрешены для запуска команд и оболочек внутри существующих
дистрибутивов. Создание/импорт (`--install`, `--import`, `--import-in-place`) и
удаление (`--unregister`) требуют review. `New-VM` и `Remove-VM` также требуют review.

## Разрушительные действия

Review сохраняется для rm/Remove-Item и аналогов, rebase/reset/clean,
канонической формы commit --amend и force push, удаления пакетов, форматирования
дисков, удаления служб и системных компонентов, разрушительных операций с
загрузчиком и образами Windows. Обычное чтение bcdedit /enum и DISM /get-features
разрешено.

У правил есть ограничения: они сопоставляют префиксы аргументов. Локальный запрет
rm не анализирует строку внутри SSH или WSL. Поздние флаги (`git commit -m msg --amend`,
`rsync -av --delete`) тоже могут попасть под разрешение. GDB, сборочные сценарии,
PowerShell cmdlets и Git hooks могут запускать дополнительный код. Поэтому
AGENTS.md требует проверять полное действие и его авторизацию, включая опасные
команды внутри гостевых систем. Универсальные pwsh/cmd/bash-префиксы не добавляются;
WSL — отдельно согласованный пользователем доверенный способ выполнения команд.

## Полная пересборка rules

На каждом запуске Codex-модуля:

1. Существующий default.rules копируется в `~/.codex/rules/backups` (Windows:
   соответствующий каталог в пользовательском профиле). Даже ранее управляемый
   firstboot файл архивируется; правила из него не переносятся.
2. Новый файл создаётся отдельно, с нуля, только из правил текущего модуля.
3. `codex execpolicy check` проверяет сгенерированный файл.
4. После успешной проверки новый файл заменяет default.rules. При ошибке проверки
   исходный файл остаётся на месте.

В Windows замена использует `Move-Item -Force`; перезапись существующего файла
описана в [документации Microsoft](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/move-item?view=powershell-7.6).

Резервные и временные файлы не оканчиваются на `.rules`, поэтому не становятся
активными правилами. На macOS backup имеет права `0600`, каталог — `0700`.
Другие пользовательские `.rules` вне default.rules не изменяются и продолжают
действовать. Это обновление исходников provisioning; на реальные Windows/macOS
хосты оно в этой сессии не устанавливалось.

## Проверки

- `python3 tests/shell/test_codex_platform_rules.py`: 36 macOS и 50 Windows
  сценариев настоящего execpolicy. Команды из сценариев не выполняются.
- macOS: исполнение только генератора rules в `/tmp`, проверка backup, полной
  пересборки, одинакового результата при повторе и сохранения старого файла
  при ошибке проверки нового.
- `bash -n macos/modules/codex.sh`
- `shellcheck -S warning macos/modules/codex.sh`
- `bash tests/shell/test_codex_config_transaction.sh`
- `bash tests/shell/test_codex_token_budget_defaults.sh`

PowerShell здесь отсутствует. Windows-правила извлекаются из литеральных объявлений
модуля и проверяются Codex, но выполнение PowerShell helpers и работа нативного
Windows sandbox требуют проверки на Windows. Обновлённый
`tests/powershell/test_codex_rules.ps1` сохраняет проверки контракта provisioning.
