# Збірка карти через Rojo

Rojo синхронізує папку з твого ПК у Studio. Сервер `rojo serve` має крутитися там, де запущений Studio.

## Один раз

1. Встанови Rojo CLI (плагін у Studio вже є): https://rojo.space/docs/v7/getting-started/installation/
2. Клонуй репозиторій на ПК (або `git pull`, якщо вже є) і перейди на гілку `claude/opus-5-5-system-prompt`.

## Кожного разу

```bat
cd <папка репозиторію>
rojo serve
```

У Studio: плагін Rojo → `localhost : 34872` → **Connect**. У `ServerScriptService` з'явиться `BuildMap`.

## Побудувати карту в режимі редагування

У Studio відкрий **View → Command Bar** і виконай:

```lua
loadstring(game.ServerScriptService.BuildMap.Source)()
```

У `Workspace` з'явиться папка `HatchMap` (земля, терасовані пагорби з деревами, три стенди для яєць, кран, табло з таймером, будівля, спавн). Повторний запуск замінює стару збірку.

У режимі Play скрипт запускається сам (карта будується на старті сервера); для постійної карти в місці використовуй Command Bar.

## Змінити карту

Правиш `src/ServerScriptService/BuildMap.server.lua` → Rojo миттєво оновлює скрипт у Studio → знову запускаєш рядок у Command Bar.
