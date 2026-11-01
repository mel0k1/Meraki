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

## Портировано из MacShell

- `Bar.qml` — верхняя стеклянная панель (по мотивам MacBar)
- `Workspaces.qml` — пилюли рабочих столов с фокусом и urgents
- `Clock.qml` — дата и время (по мотивам ClockWidget)

Hyprland- и Quickshell-зависимости оригинала заменены на sway-IPC через
`bridge`; рантайм — чистый Qt Quick на Windows.

## Roadmap

1. Док с иконками приложений (MacDock): иконки через SHGetFileInfo,
   миниатюры окон, генси-анимация
2. Шейдеры Liquid Glass из MacShell (`*.frag` → qsb, `qt_add_shaders`)
3. Центр уведомлений на `SWINE_IPC_GET_NOTIFICATIONS`
4. Виджеты рабочего стола (погода, календарь, музыка) из MacShell
5. Трей и меню запуска в QML-баре, мультидисплей
