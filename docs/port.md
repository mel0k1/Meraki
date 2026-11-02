# Порт

## Источники

| Часть | Откуда | Лицензия |
| --- | --- | --- |
| Движок | [SwineWM](https://github.com/staalmannen/SwineWM) | MIT |
| Интерфейс | [MacShell](https://github.com/0-ss/MacShell) | MIT |

## Изменения в движке

- `swinewm/main.c` — запуск и остановка QML-слоя под `MERAKI_QML`
- `swinewm/CMakeLists.txt` — опция `MERAKI_QML`, Qt Quick, ресурсы QML
- `swinewm/config.in` — нативный бар скрыт (`bar mode invisible`)
- `swinewm/qmlbar/` — сам слой (новое)
- `swinewm/qmlbar/capture.cpp` — `Windows.Graphics.Capture` через C++/WinRT:
  `LiveThumb` (живое превью окна в QML) и `MerakiFx` (стоп-кадр окна,
  полноэкранный оверлей для genie, кэш кадров для восстановления)
- `tools/switcher/` — переключатель оболочки: две кнопки — «Поставить Meraki»
  (движок сам прописывается в HKCU Winlogon Shell через `swinewm --set-shell`)
  и «Вернуть Explorer» (`--unset-shell`), плюс статус оболочки и процессов

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
  (`Windows.Graphics.Capture`, кадры через staging-текстуру в QImage)
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
  в слот дока (bezье 0.22/0.8/0.28/1.0, 0.42 с); восстановление — обратная
  деформация из кэша кадра, затем `SW_RESTORE` и фейд оверлея 180 мс

Фон стекла — обои плюс прямоугольники окон из IPC-дерева; уведомления
берутся из встроенного в движок Mako (`notify-send.exe` из пакета движка
кладёт заметки прямо в центр).

Hyprland- и Quickshell-зависимости оригинала заменены на sway-IPC через
`bridge`; рантайм — чистый Qt Quick на Windows.

## Roadmap

1. Виджеты рабочего стола (погода, календарь, музыка) из MacShell
2. Трей и меню запуска в QML-баре, мультидисплей
3. Иконки UWP-приложений
