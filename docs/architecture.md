# Архитектура

Один процесс `meraki.exe` (цель CMake — `swinewm`, OUTPUT_NAME `meraki`)
объединяет движок окон и оболочку Meraki.

## Движок (`engine/`)

Копия SwineWM: тилинг-менеджер окон на Win32 (конфиг sway), встроенный бар
в стиле Waybar (в Meraki скрыт), Mako-совместимые уведомления
(`notify-send.exe`, `makoctl.exe`), IPC-сервер i3/sway по именованному
каналу `\\.\pipe\swinewm-ipc.<user>`, лаунчер `swinemenu.exe`,
переключатель оболочки `switcher.exe` (`tools/switcher`: две кнопки —
«Поставить Meraki» через `meraki --set-shell` и «Вернуть Explorer»).

Слои движка:

- `swine_common` — переносимое ядро (json, ipc-client, утилиты): собирается
  и на Linux, покрыто тестами;
- `swinewm_core` — дерево окон, команды, конфиг, ipc-json;
- `swinewm/win32/` — платформенный слой: окна, ввод, бар, уведомления.

## Слой Meraki (`engine/swinewm/qmlbar/`)

Qt Quick внутри процесса движка:

- `qmlbar.cpp` — бары (окно на каждый экран, frameless, поверх всех,
  прозрачный фон) и объект `bridge` для QML: свойства `workspaces`,
  `activeName`, команда `switchTo(n)`; `MerakiDock` — по экземпляру на
  экран: список окон из `IPC_GET_TREE` (id, hwnd, iconic), иконки, пины
  (`togglePin`, drag-реордер — `reorderPin`, сохранение в
  `~/.swinewm/dock.json` с синхронизацией копий по mtime), smart-hide
  (`updateSmartHide`: окно налегло на полосу дока — док уезжает, курсор
  у кромки — выезжает; резерв рабочей области через атомарный счётчик
  `meraki_dock_reserve_px`, читаемый потоком раскладки в
  `win32_shell_reserve`), контекстное меню пина — отдельное popup-окно
  `dock/DockMenu.qml` (`showMenu`, закрытие приложения — `[con_id=N] kill`);
  `MerakiCenter`:
  панель уведомлений `center/Center.qml` — активные + история из
  `SWINE_IPC_GET_NOTIFICATIONS`/`_HISTORY`, закрытие —
  `SWINE_IPC_CLOSE_NOTIFICATION`, тумблер — клик по часам (`toggleCenter`),
  «Не беспокоить» (`toggleDnd`, хранится в `~/.swinewm/settings.json`):
  центр копит уведомления, но тосты не всплывают,
  окно без региона ввода вне панели (клики мимо проходят в окна);
  `MerakiSpotlight` — пилюля поиска `apps/Spotlight.qml` (Super+Space):
  общий скан «Пуска» с Launchpad (`meraki_scan_apps`), числовые запросы
  считает QJSEngine (Enter копирует ответ в буфер);
  `MerakiCC` — Control Center `center/CC.qml`: тайлы Wi-Fi/Bluetooth/
  ночной свет (страницы `ms-settings:`), тумблер DND, громкость и медиа
  из sysinfo/SMTC;
- `bridge.c` — поток-подписчик IPC (`SUBSCRIBE
  ["workspace","window","notification","binding"]`), события кладёт в очередь,
  QML-поток забирает по таймеру; notification-событие обновляет список
  уведомлений, binding-событие с командой `nop meraki:*` открывает
  интерфейсы оболочки (Win+D → Launchpad, Win+Space → Spotlight,
  Win+Shift+S → Control Center, Win+Shift+D → DND) без движковых действий;
- `capture.cpp` — `Windows.Graphics.Capture`: `LiveThumb` (живое превью
  окна, кадры GPU -> staging -> QImage) и `MerakiFx` (джинн: оверлей на весь
  экран, стоп-кадр, `SW_MINIMIZE`/`SW_RESTORE` с отключённым DWM-переходом);
- `qml/Meraki/*.qml` — интерфейс: бар (работает столы, трей `Tray.qml`,
  Control Center и поиск), док с иконками и Liquid Glass (`shaders/`,
  `glass/`, `dock/`), живые превью (`dock/Preview.qml`), генси
  (`MinimizeFx.qml`), меню запуска (`apps/Launchpad.qml`), Spotlight
  (`apps/Spotlight.qml`), виджеты (`widgets/`: часы, календарь, погода,
  музыка, система — кольца ЦП/ОЗУ, заметка-стикер), пилюли рабочих
  столов, часы.

Виджеты — окна слоя рабочего стола (по одному на экран, `screens` в
`widgets.json`): движок держит их прямо над обоями (`win32_desktop_layer_*`
в `wallpaper.c`), регион ввода только под карточками; раскладка, размеры и
состав карточек — в `~/.swinewm/widgets.json` (пример `pack/widgets.example.json`);
карточки перетаскиваются мышью, позиции падают в секцию `positions` того же
файла, сам файл применяется на лету (QFileSystemWatcher); медиа-данные даёт
`media.cpp` (Windows GSMTC через C++/WinRT), погода — open-meteo прямо из QML,
ЦП/ОЗУ — общий `sysinfo` движка (снимок раз в 2 с), заметка хранит текст в
`~/.swinewm/notes.txt`.

Хотклен мониторов: `screenAdded`/`screenRemoved` QGuiApplication — бары,
доки и виджеты создаются/снимаются на ходу; центр уведомлений следует за
основным экраном (`primaryScreenChanged`). Низкоуровневый хук клавиатуры
живёт в отдельном потоке со своим циклом сообщений — биндинги не пропадают,
когда главный поток занят; список биндингов читается под rw-блокировкой на
время перезагрузки конфига.

Генси: клик по иконке сфокусированного окна -> стоп-кадр окна -> окно
сворачивается -> вершинный шейдер `genie.vert` (сетка 6x64) льёт кадр в слот
иконки за 0.42 с; клик по свернутому окну проигрывает то же назад из кэша
кадра и возвращает окно под фейдящийся оверлей.

## Границы

Слой Meraki не знает внутренних структур движка, движок не знает о QML:
обмен только по штатному sway-IPC (loopback через `ipc-client`). Поэтому
QML-слой можно вынести в отдельный процесс или гонять под обычным sway —
протокол тот же. Отключение слоя: `-DMERAKI_QML=OFF` или `bar { position top }`.
