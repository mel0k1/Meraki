# Порт

## Источники

| Часть | Откуда | Лицензия |
| --- | --- | --- |
| Движок | [SwineWM](https://github.com/staalmannen/SwineWM) | MIT |
| Интерфейс | [MacShell](https://github.com/0-ss/MacShell) | MIT |

## Изменения в движке

- `swinewm/main.c` — запуск и остановка QML-слоя под `MERAKI_QML`
- `swinewm/CMakeLists.txt` — опция `MERAKI_QML`, Qt Quick, ресурсы QML
- `swinewm/config.in` — нативный бар скрыт (`bar mode invisible`); Meraki —
  DE: `default_floating yes` (окна плавают, как в Mac), `default_border none`,
  обои не навязываются (см. wallpaper.c)
- `swinewm/tree/view.c` + `commands/settings.c` — `default_floating yes|no`:
  новые окна добавляются на рабочий стол как плавающие и сохраняют позицию/
  размер от приложения (поведение DE, а не оконника); тайлинг возвращается
  `default_floating no`
- `swinewm/qmlbar/` — сам слой (новое)
- `swinewm/qmlbar/media.cpp` — `MerakiMedia`: системный медиа-контрол через
  `GlobalSystemMediaTransportControlsSessionManager` (C++/WinRT): трек,
  исполнитель, play/pause, next/prev
- `swinewm/win32/tray.c` — для QML-слоя: `win32_tray_force` (хост
  уведомлений без модуля трея в C-баре), `win32_tray_set_listener`
  (обратный вызов об изменениях), `win32_tray_icon_bits` (копия иконки)
- `swinewm/win32/wallpaper.c` — `win32_desktop_layer_register`/
  `win32_desktop_layer_place`: окно виджетов живёт прямо над обоями и не
  мешает раскладке обоев/десктопа; без `output * bg` в конфиге движок
  рисует текущие обои Windows пользователя (`SPI_GETDESKWALLPAPER`) — свои
  обои Meraki не ставит
- `swinewm/qmlbar/capture.cpp` — `Windows.Graphics.Capture` через C++/WinRT:
  `LiveThumb` (живое превью окна в QML) и `MerakiFx` (стоп-кадр окна,
  полноэкранный оверлей для genie, кэш кадров для восстановления)
- `tools/switcher/` — переключатель оболочки: две кнопки — «Поставить Meraki»
  (движок сам прописывается в HKCU Winlogon Shell через `swinewm --set-shell`)
  и «Вернуть Explorer» (`--unset-shell`); подтверждение действия, кнопка
  активной оболочки неактивна, статус обновляется сам (таймер), безопасное
  чтение реестра с терминатором

## Портировано из MacShell

- `Bar.qml` — верхняя стеклянная панель (по мотивам MacBar)
- `Workspaces.qml` — пилюли рабочих столов с фокусом и urgents
- `Clock.qml` — дата и время (по мотивам ClockWidget)
- `shaders/liquidglass.frag`, `shaders/dockglass.frag` — Liquid Glass: SDF
  скруглённого прямоугольника, безель-сквиркл, Snell, дисперсия, зерно;
  сборка через `qt_add_shaders`
- `glass/LiquidGlass.qml` — стеклянная плита: фикс-захват фона, пре-размытие
  MultiEffect, ShaderEffect, запасной Rectangle при ошибке шейдера
- `dock/Dock.qml`, `dock/DockIcon.qml`, `dock/DockTip.qml` — док: магнификация
  косинусным колоколом, индикаторы запуска, bounce, всплывающие метки
- `qmlbar.cpp: MerakiDock` — окна через `IPC_GET_TREE`, иконки
  `SHGetFileInfo` + jumbo-лист с кэшем в `~/.swinewm/cache/icons`, обои
  через `SPI_GETDESKWALLPAPER`, пины в `~/.swinewm/dock.json`, регион ввода
  шагами 64 px
- `qmlbar.cpp: MerakiCenter` — центр уведомлений: активные + история через
  `SWINE_IPC_GET_NOTIFICATIONS`/`_HISTORY` (mako-совместимый JSON), закрытие
  — `SWINE_IPC_CLOSE_NOTIFICATION`, клик по заметке — фокус приложения,
  тумблер — `toggleCenter` (клик по часам в баре)
- `dock/Preview.qml` + `LiveThumb` — живое превью окна при наведении
  (`Windows.Graphics.Capture`, кадры через staging-текстуру в QImage);
  для мультиокна — переключение стрелками ‹ › со счётчиком 1/N, клик по
  превью — фокус окна, кнопка × — закрыть окна (`[con_id] kill`)
- `dock/DockMenu.qml` — контекстное меню пина (правый клик по иконке):
  закрепить/открепить, закрыть все окна приложения; пины пишутся в
  `~/.swinewm/dock.json`, закреплённые без окон запускаются по клику
- `glass/DockGlassPanel.qml` — стеклянный пузырь (Meraki-версия
  DockGlassPanel MacShell): LiquidGlass + область контента, общий пресет
  для тултипа и центра уведомлений
- `dock/DockTip.qml` — тултип с размытым фоном: появление через 320 мс,
  между иконками переезжает без повторной задержки; для запущенных
  приложений вместо него показывается живое превью
- `center/Center.qml` — панель уведомлений справа сверху: выезжает из-под
  бара (240 мс), стеклянный фон DockGlassPanel, удаление заметки и
  «Очистить», критические — с красной меткой, относительное время;
  регион ввода сжимается под панель, клики мимо проходят в окна
- `MinimizeFx.qml` + `shaders/genie.vert`/`genie.frag` — генси: стоп-кадр
  окна, DWM-переход отключается, окно сворачивается, сетка 6x64 льёт кадр
  в слот дока (безье 0.22/0.8/0.28/1.0, 0.42 с); восстановление — обратная
  деформация из кэша кадра, затем `SW_RESTORE` и фейд оверлея 180 мс
- UWP-иконки (`qmlbar.cpp`): AUMID окна — через `SHGetPropertyStoreForWindow`
  (`System.AppUserModel.ID`) или `Windows.UI.Core.CoreWindow` +
  `GetApplicationUserModelId`; иконка — `shell:AppsFolder/<aumid>` через
  `IShellItemImageFactory::GetImage` (SIIGBF_ICONONLY, PNG-премультипликация
  разворачивается), кэш в `~/.swinewm/cache/icons`; UWP-окна группируются в
  доке по AUMID (а не по ApplicationFrameHost), имя — отображаемое имя из
  shell-элемента, пин запускается через `explorer.exe shell:AppsFolder/...`
- `Tray.qml` — трей в баре слева от часов: иконки хоста уведомлений
  (`Shell_TrayWnd`-протокол движка), клики и ховер пересылаются программам
  (`win32_tray_mouse`/`win32_tray_hover`), хост-прямоугольник — область
  трея в баре (для меню программ); снапшот иконок через listener движка
- `apps/Launchpad.qml` + `MerakiApps` — меню запуска: все ярлыки меню «Пуск»
  (`.lnk`/`.url` из `FOLDERID_Programs` и `FOLDERID_CommonPrograms`, без
  автозагрузки), поиск по мере ввода, Enter — первая программа, запуск —
  `ShellExecuteExW`, иконки jumbo из ярлыка; открывается кнопкой-сеткой в
  левом углу бара, Esc/клик мимо — закрыть
- `widgets/` — виджеты рабочего стола: слой отдельным окном прямо над
  обоями (`win32_desktop_layer_*`, WS_EX_NOACTIVATE, регион ввода только
  под карточками) на стеклянных панелях DockGlassPanel: часы (аналоговые,
  плавная секундная), календарь (месяц по локали системы, подсветка
  сегодня), погода (open-meteo, WMO-код -> глиф WeatherGlyph, почасовой
  прогноз на 4 часа, город/координаты из `~/.swinewm/widgets.json`, по
  умолчанию Москва) и музыка (трек/исполнитель/кнопки из системного
  медиа-контрола)
- настройка виджетов `~/.swinewm/widgets.json` (пример —
  `pack/widgets.example.json`): `screens` (`all`/`primary`), `side`
  (`right`/`left`), `margin`, `top`, `spacing` и по карточке — `enabled`,
  размеры, для часов `seconds`, для погоды `units` (`celsius`/`fahrenheit`)
  и город/координаты; старые плоские ключи `latitude`/`longitude`/`city`
  продолжают работать; файл применяется на лету (QFileSystemWatcher),
  секция `positions` — сохранённые мышью позиции карточек
- мультидисплей: бар с часами создаётся на каждом экране (трей — только
  на основном, `viewPrimary`), по экземпляру дока на экран (первый —
  основной, пины синхронизируются по mtime `dock.json`), виджеты на всех
  экранах (или одном — `screens`); стеклу через `viewX`/`viewY` известен
  сдвиг монитора, глобальные координаты (меню пина, слоты генси) считаются
  в системе координат своего экрана
- хотклен мониторов: `screenAdded`/`screenRemoved` QGuiApplication —
  бары, доки и виджеты создаются/снимаются на ходу, центр уведомлений
  следует за основным экраном (`primaryScreenChanged`)
- перетаскивание виджетов мышью: карточку можно тащить за любую её часть
  (у медиа — кроме кнопок), позиция сохраняется в `positions` widgets.json
- центр уведомлений: закрывается кликом мимо (деактивация окна),
  «Очистить» убирает и активные, и историю, счётчик — точка на часах бара
- клавиатура: LL-хук вынесен в отдельный поток с собственным циклом
  сообщений (биндинги не пропадают при загрузке главного потока), список
  биндингов читается под rw-блокировкой; Win+D в дефолтном конфиге —
  `nop meraki:launchpad`, оболочка открывает Launchpad (мост через
  binding-события IPC); `exec` сначала ищет программу рядом с meraki.exe

Фон стекла — обои плюс прямоугольники окон из IPC-дерева; уведомления
берутся из встроенного в движок Mako (`notify-send.exe` из пакета движка
кладёт заметки прямо в центр).

Hyprland- и Quickshell-зависимости оригинала заменены на sway-IPC через
`bridge`; рантайм — чистый Qt Quick на Windows.

## Roadmap

1. Центр уведомлений: действия в заметках, настройки
2. Тултипы дока: докрутка и полировка

Тег и GitHub Release с артефактами сделаны (v0.3.0–v0.5.0).
