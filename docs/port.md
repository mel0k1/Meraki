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
- `dock/Preview.qml` + `LiveThumb` — живое превью окна при наведении
  (`Windows.Graphics.Capture`, кадры через staging-текстуру в QImage)
- `MinimizeFx.qml` + `shaders/genie.vert`/`genie.frag` — генси: стоп-кадр
  окна, DWM-переход отключается, окно сворачивается, сетка 6x64 льёт кадр
  в слот дока (bezье 0.22/0.8/0.28/1.0, 0.42 с); восстановление — обратная
  деформация из кэша кадра, затем `SW_RESTORE` и фейд оверлея 180 мс

Фон стекла — обои плюс прямоугольники окон из IPC-дерева (UWP-иконки —
следующий шаг); тултип — без хвоста и размытия фона (DockGlassPanel-стиль —
следующий шаг).

Hyprland- и Quickshell-зависимости оригинала заменены на sway-IPC через
`bridge`; рантайм — чистый Qt Quick на Windows.

## Roadmap

1. Контекстное меню пина, тултипы с размытым фоном (DockGlassPanel)
2. Центр уведомлений на `SWINE_IPC_GET_NOTIFICATIONS`
3. Виджеты рабочего стола (погода, календарь, музыка) из MacShell
4. Трей и меню запуска в QML-баре, мультидисплей
