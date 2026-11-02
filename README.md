# Meraki

Альтернативная среда рабочего стола для Windows, заменяющая explorer.exe.
macOS-подобный интерфейс, портированный с
[MacShell](https://github.com/0-ss/MacShell), на движке
[SwineWM](https://github.com/staalmannen/SwineWM): тилинг окон как в Sway,
IPC-протокол i3/sway, встроенные уведомления в духе Mako.

## Состав

- `engine/` — движок: копия SwineWM (MIT) и QML-слой Meraki, собираемый
  внутрь `swinewm.exe` (опция `MERAKI_QML`)
- `docs/architecture.md` — как это устроено
- `docs/port.md` — что откуда портировано, roadmap

## Сборка

Windows 10/11: MSVC 2022, CMake 3.20+, Qt 6.7+ (Quick):

    cmake -S engine/swinewm -B build -A x64
    cmake --build build --config Release

Без Qt-слоя: `-DMERAKI_QML=OFF`. Переносимое ядро и тесты собираются на
Linux:

    cmake -S engine/swinewm -B build && ctest --test-dir build

## Запуск

    build\swinewm\Release\swinewm.exe

Заменить explorer.exe при входе в систему (обратимо):

    swinewm.exe --set-shell
    swinewm.exe --unset-shell

Рядом с Explorer: `swinewm.exe --set-autostart` (экспериментально). После
сбоя оболочки: `swinewm.exe --recover` вернёт спрятанные окна.

Конфиг: `%USERPROFILE%\.swinewm\config` — синтаксис sway. Нативный бар
движка скрыт (`bar mode invisible`): верхнюю панель и док рисует QML-слой
Meraki; вернуть движковый бар можно, заменив строку на `bar { position top }`.

Мультидисплей: бар, док и виджеты создаются на каждом мониторе (трей —
на основном). Виджеты настраиваются файлом `%USERPROFILE%\.swinewm\widgets.json`
(какие карточки показывать, размеры, сторона экрана, отступы, единицы
погоды) — пример в `pack/widgets.example.json`.

## Лицензии

Код Meraki — GPL-3.0 (`LICENSE`). Движок SwineWM — MIT (`engine/LICENSE`),
интерфейс портирован с MacShell (MIT).
