# Архитектура

Один процесс `swinewm.exe` объединяет движок окон и оболочку Meraki.

## Движок (`engine/`)

Копия SwineWM: тилинг-менеджер окон на Win32 (конфиг sway), встроенный бар
в стиле Waybar (в Meraki скрыт), Mako-совместимые уведомления
(`notify-send.exe`, `makoctl.exe`), IPC-сервер i3/sway по именованному
каналу `\\.\pipe\swinewm-ipc.<user>`, лаунчер `swinemenu.exe`,
переключатель оболочки `switcher.exe` (`tools/switcher`: две кнопки —
«Поставить Meraki» через `swinewm --set-shell` и «Вернуть Explorer»).

Слои движка:

- `swine_common` — переносимое ядро (json, ipc-client, утилиты): собирается
  и на Linux, покрыто тестами;
- `swinewm_core` — дерево окон, команды, конфиг, ipc-json;
- `swinewm/win32/` — платформенный слой: окна, ввод, бар, уведомления.

## Слой Meraki (`engine/swinewm/qmlbar/`)

Qt Quick внутри процесса движка:

- `qmlbar.cpp` — окно бара (frameless, поверх всех, прозрачный фон) и
  объект `bridge` для QML: свойства `workspaces`, `activeName`, команда
  `switchTo(n)`; `MerakiDock`: список окон из `IPC_GET_TREE` (id, hwnd,
  iconic), иконки, пины (`togglePin`, сохранение в `~/.swinewm/dock.json`),
  контекстное меню пина — отдельное popup-окно `dock/DockMenu.qml`
  (`showMenu`, закрытие приложения — `[con_id=N] kill`); `MerakiCenter`:
  панель уведомлений `center/Center.qml` — активные + история из
  `SWINE_IPC_GET_NOTIFICATIONS`/`_HISTORY`, закрытие —
  `SWINE_IPC_CLOSE_NOTIFICATION`, тумблер — клик по часам (`toggleCenter`),
  окно без региона ввода вне панели (клики мимо проходят в окна)
- `bridge.c` — поток-подписчик IPC (`SUBSCRIBE
  ["workspace","window","notification"]`), события кладёт в очередь,
  QML-поток забирает по таймеру; notification-событие обновляет список
  уведомлений;
- `capture.cpp` — `Windows.Graphics.Capture`: `LiveThumb` (живое превью
  окна, кадры GPU -> staging -> QImage) и `MerakiFx` (джинн: оверлей на весь
  экран, стоп-кадр, `SW_MINIMIZE`/`SW_RESTORE` с отключённым DWM-переходом);
- `qml/Meraki/*.qml` — интерфейс: бар, док с иконками и Liquid Glass
  (`shaders/`, `glass/`, `dock/`), живые превью (`dock/Preview.qml`),
  генси (`MinimizeFx.qml`), пилюли рабочих столов, часы.

Генси: клик по иконке сфокусированного окна -> стоп-кадр окна -> окно
сворачивается -> вершинный шейдер `genie.vert` (сетка 6x64) льёт кадр в слот
иконки за 0.42 с; клик по свернутому окну проигрывает то же назад из кэша
кадра и возвращает окно под фейдящийся оверлей.

## Границы

Слой Meraki не знает внутренних структур движка, движок не знает о QML:
обмен только по штатному sway-IPC (loopback через `ipc-client`). Поэтому
QML-слой можно вынести в отдельный процесс или гонять под обычным sway —
протокол тот же. Отключение слоя: `-DMERAKI_QML=OFF` или `bar { position top }`.
