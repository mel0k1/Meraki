# Архитектура

Один процесс `swinewm.exe` объединяет движок окон и оболочку Meraki.

## Движок (`engine/`)

Копия SwineWM: тилинг-менеджер окон на Win32 (конфиг sway), встроенный бар
в стиле Waybar (в Meraki скрыт), Mako-совместимые уведомления
(`notify-send.exe`, `makoctl.exe`), IPC-сервер i3/sway по именованному
каналу `\\.\pipe\swinewm-ipc.<user>`, лаунчер `swinemenu.exe`.

Слои движка:

- `swine_common` — переносимое ядро (json, ipc-client, утилиты): собирается
  и на Linux, покрыто тестами;
- `swinewm_core` — дерево окон, команды, конфиг, ipc-json;
- `swinewm/win32/` — платформенный слой: окна, ввод, бар, уведомления.

## Слой Meraki (`engine/swinewm/qmlbar/`)

Qt Quick внутри процесса движка:

- `qmlbar.cpp` — окно бара (frameless, поверх всех, прозрачный фон) и
  объект `bridge` для QML: свойства `workspaces`, `activeName`, команда
  `switchTo(n)`;
- `bridge.c` — поток-подписчик IPC (`SUBSCRIBE ["workspace","window"]`),
  события кладёт в очередь, QML-поток забирает по таймеру;
- `qml/Meraki/*.qml` — интерфейс: бар, пилюли рабочих столов, часы.

## Границы

Слой Meraki не знает внутренних структур движка, движок не знает о QML:
обмен только по штатному sway-IPC (loopback через `ipc-client`). Поэтому
QML-слой можно вынести в отдельный процесс или гонять под обычным sway —
протокол тот же. Отключение слоя: `-DMERAKI_QML=OFF` или `bar { position top }`.
